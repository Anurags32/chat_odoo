# -*- coding: utf-8 -*-
import base64
import hashlib
import hmac
import logging
import time
from odoo import http, fields, _
from odoo.http import request

_logger = logging.getLogger(__name__)


class WebRtcCallController(http.Controller):

    # =========================================================================
    # 1. ICE Servers (STUN + TURN with Time-Limited Credentials)
    # =========================================================================
    @http.route('/webrtc/ice_servers', type='json', auth='user', methods=['POST'])
    def get_ice_servers(self):
        """
        Returns STUN & TURN server configurations.
        If coturn is configured in ir.config_parameter, generates time-limited
        credentials using the standard HMAC-SHA1 algorithm (turn_shared_secret).
        """
        user = request.env.user
        partner = user.partner_id
        get_param = request.env['ir.config_parameter'].sudo().get_param

        turn_url = get_param('webrtc_call.turn_url', 'turn:turn.example.com:3478')
        turn_urls_tls = get_param('webrtc_call.turn_urls_tls', 'turns:turn.example.com:5349')
        turn_secret = get_param('webrtc_call.turn_secret')
        stun_url = get_param('webrtc_call.stun_url', 'stun:stun.l.google.com:19302')

        ice_servers = [
            {'urls': [stun_url, 'stun:stun1.l.google.com:19302']},
        ]

        if turn_secret:
            # Generate time-limited credentials valid for 24 hours
            ttl_seconds = 86400
            expiry_timestamp = int(time.time()) + ttl_seconds
            username = f"{expiry_timestamp}:{partner.id}"

            # HMAC-SHA1 credential generation
            key = turn_secret.encode('utf-8')
            data = username.encode('utf-8')
            digest = hmac.new(key, data, hashlib.sha1).digest()
            credential = base64.b64encode(digest).decode('utf-8')

            ice_servers.append({
                'urls': [turn_url, turn_urls_tls],
                'username': username,
                'credential': credential,
            })
            _logger.info("[WebRTC ICE] Generated TURN credentials for user %s (valid for %ss)", user.id, ttl_seconds)
        else:
            _logger.warning("[WebRTC ICE] 'webrtc_call.turn_secret' not set. Returning public STUN only.")

        return {
            'status': 'success',
            'ice_servers': ice_servers,
        }

    # =========================================================================
    # 2. Push Notification Device Registration
    # =========================================================================
    @http.route('/webrtc/device/register', type='json', auth='user', methods=['POST'])
    def register_device(self, platform, device_id=None, fcm_token=None, voip_token=None):
        """Register or update device push token for the current user."""
        if platform not in ('android', 'ios'):
            return {'status': 'error', 'message': "Invalid platform. Must be 'android' or 'ios'."}

        device = request.env['webrtc.device'].sudo().register_device(
            user_id=request.env.uid,
            platform=platform,
            device_id=device_id,
            fcm_token=fcm_token,
            voip_token=voip_token,
        )
        return {
            'status': 'success',
            'device_id': device.id,
        }

    # =========================================================================
    # 3. Call Lifecycle: Start
    # =========================================================================
    @http.route('/webrtc/call/start', type='json', auth='user', methods=['POST'])
    def call_start(self, callee_partner_id, call_type='audio'):
        """Initiate an audio or video call to another partner."""
        caller = request.env.user.partner_id
        callee = request.env['res.partner'].browse(int(callee_partner_id))

        if not callee.exists():
            return {'status': 'error', 'message': 'Callee partner does not exist.'}

        if caller.id == callee.id:
            return {'status': 'error', 'message': 'Cannot initiate a call to yourself.'}

        if call_type not in ('audio', 'video'):
            return {'status': 'error', 'message': "Invalid call_type. Must be 'audio' or 'video'."}

        # Check if callee is currently engaged in another call
        active_callee_call = request.env['webrtc.call'].sudo().search([
            '|',
            ('caller_id', '=', callee.id),
            ('callee_id', '=', callee.id),
            ('state', 'in', ['ringing', 'accepted']),
        ], limit=1)

        if active_callee_call:
            # Callee is busy
            busy_call = request.env['webrtc.call'].sudo().create({
                'caller_id': caller.id,
                'callee_id': callee.id,
                'call_type': call_type,
                'state': 'busy',
                'end_time': fields.Datetime.now(),
                'end_reason': 'callee_busy',
            })
            return {
                'status': 'busy',
                'message': f"{callee.name} is currently on another call.",
                'call': busy_call._to_dict(),
            }

        # Create new ringing call record
        call = request.env['webrtc.call'].sudo().create({
            'caller_id': caller.id,
            'callee_id': callee.id,
            'call_type': call_type,
            'state': 'ringing',
        })

        # 1. Notify Callee via Foreground WebSocket Bus
        call._send_bus_event(callee, 'incoming_call')

        # 2. Dispatch Background Push to Wake Callee App
        request.env['webrtc.device'].sudo()._send_call_push(
            partner=callee,
            call_id=call.id,
            call_type=call_type,
            caller_name=caller.name,
            action='incoming',
        )

        return {
            'status': 'success',
            'call': call._to_dict(),
        }

    # =========================================================================
    # 4. Call Lifecycle: Accept
    # =========================================================================
    @http.route('/webrtc/call/accept', type='json', auth='user', methods=['POST'])
    def call_accept(self, call_id):
        """Callee accepts the incoming call."""
        call = request.env['webrtc.call'].browse(int(call_id))
        if not call.exists():
            return {'status': 'error', 'message': 'Call not found.'}

        current_partner = request.env.user.partner_id
        if call.callee_id.id != current_partner.id:
            return {'status': 'error', 'message': 'Only the callee can accept this call.'}

        if call.state != 'ringing':
            return {'status': 'error', 'message': f'Call cannot be accepted in state: {call.state}'}

        call.action_accept()
        return {
            'status': 'success',
            'call': call._to_dict(),
        }

    # =========================================================================
    # 5. Call Lifecycle: Reject
    # =========================================================================
    @http.route('/webrtc/call/reject', type='json', auth='user', methods=['POST'])
    def call_reject(self, call_id, reason='rejected'):
        """Callee rejects the incoming call."""
        call = request.env['webrtc.call'].browse(int(call_id))
        if not call.exists():
            return {'status': 'error', 'message': 'Call not found.'}

        current_partner = request.env.user.partner_id
        if call.callee_id.id != current_partner.id:
            return {'status': 'error', 'message': 'Only the callee can reject this call.'}

        call.action_reject(reason=reason)
        return {
            'status': 'success',
            'call': call._to_dict(),
        }

    # =========================================================================
    # 6. Call Lifecycle: Cancel
    # =========================================================================
    @http.route('/webrtc/call/cancel', type='json', auth='user', methods=['POST'])
    def call_cancel(self, call_id):
        """Caller cancels the call before callee answers."""
        call = request.env['webrtc.call'].browse(int(call_id))
        if not call.exists():
            return {'status': 'error', 'message': 'Call not found.'}

        current_partner = request.env.user.partner_id
        if call.caller_id.id != current_partner.id:
            return {'status': 'error', 'message': 'Only the caller can cancel this call.'}

        call.action_cancel()
        return {
            'status': 'success',
            'call': call._to_dict(),
        }

    # =========================================================================
    # 7. Call Lifecycle: End
    # =========================================================================
    @http.route('/webrtc/call/end', type='json', auth='user', methods=['POST'])
    def call_end(self, call_id, reason='normal'):
        """Either participant ends the ongoing call."""
        call = request.env['webrtc.call'].browse(int(call_id))
        if not call.exists():
            return {'status': 'error', 'message': 'Call not found.'}

        current_partner = request.env.user.partner_id
        if current_partner.id not in (call.caller_id.id, call.callee_id.id):
            return {'status': 'error', 'message': 'You are not a participant in this call.'}

        call.action_end(reason=reason)
        return {
            'status': 'success',
            'call': call._to_dict(),
        }

    # =========================================================================
    # 8. WebRTC Signaling Relay (SDP Offer / Answer / ICE Candidates)
    # =========================================================================
    @http.route('/webrtc/signal', type='json', auth='user', methods=['POST'])
    def signal(self, call_id, type, payload):
        """
        Relays WebRTC peer-to-peer signaling packets (offer, answer, candidate)
        to the other participant via Odoo 18 bus.bus.
        """
        if type not in ('offer', 'answer', 'candidate'):
            return {'status': 'error', 'message': "Invalid signal type. Must be 'offer', 'answer', or 'candidate'."}

        call = request.env['webrtc.call'].browse(int(call_id))
        if not call.exists():
            return {'status': 'error', 'message': 'Call record not found.'}

        current_partner = request.env.user.partner_id
        if current_partner.id not in (call.caller_id.id, call.callee_id.id):
            return {'status': 'error', 'message': 'Unauthorized: You are not a participant in this call.'}

        if call.state not in ('ringing', 'accepted'):
            return {'status': 'error', 'message': f'Cannot relay signaling for call in state: {call.state}'}

        # Target the other peer
        recipient_partner = call.callee_id if current_partner.id == call.caller_id.id else call.caller_id

        signal_message = {
            'event': 'signal',
            'call_id': call.id,
            'type': type,
            'payload': payload,
            'sender_id': current_partner.id,
        }

        _logger.debug(
            "[WebRTC Signal] Relaying '%s' for Call ID %s: %s -> %s",
            type,
            call.id,
            current_partner.name,
            recipient_partner.name,
        )
        request.env['bus.bus']._sendone(recipient_partner, 'webrtc_call', signal_message)

        return {'status': 'success'}

    # =========================================================================
    # 9. Call History
    # =========================================================================
    @http.route('/webrtc/call/history', type='json', auth='user', methods=['POST'])
    def call_history(self, limit=30, offset=0):
        """Returns call log history for current user."""
        current_partner = request.env.user.partner_id
        calls = request.env['webrtc.call'].search([
            '|',
            ('caller_id', '=', current_partner.id),
            ('callee_id', '=', current_partner.id),
        ], limit=limit, offset=offset)

        return {
            'status': 'success',
            'calls': [call._to_dict() for call in calls],
            'total': len(calls),
        }
