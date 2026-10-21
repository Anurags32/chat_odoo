# -*- coding: utf-8 -*-
from datetime import datetime
import json
import logging
import urllib.request
import urllib.error
from odoo import models, fields, api, _

_logger = logging.getLogger(__name__)


class WebrtcDevice(models.Model):
    _name = 'webrtc.device'
    _description = 'WebRTC User Device Push Token'
    _order = 'last_seen desc, id desc'

    user_id = fields.Many2one(
        'res.users',
        string='User',
        required=True,
        ondelete='cascade',
        index=True,
    )
    partner_id = fields.Many2one(
        'res.partner',
        string='Partner',
        related='user_id.partner_id',
        store=True,
        index=True,
    )
    platform = fields.Selection(
        [('android', 'Android'), ('ios', 'iOS')],
        string='Platform',
        required=True,
        index=True,
    )
    fcm_token = fields.Char(string='FCM Push Token', index=True)
    voip_token = fields.Char(string='APNs VoIP Token (iOS PushKit)', index=True)
    device_id = fields.Char(string='Unique Device ID', index=True)
    active = fields.Boolean(string='Active', default=True)
    last_seen = fields.Datetime(string='Last Seen', default=fields.Datetime.now)

    _sql_constraints = [
        ('user_device_unique', 'unique(user_id, device_id)', 'A user can only register each device ID once.'),
    ]

    @api.model
    def register_device(self, user_id, platform, device_id=None, fcm_token=None, voip_token=None):
        """Register or update a user device for push notifications."""
        now = fields.Datetime.now()
        domain = [('user_id', '=', user_id)]
        if device_id:
            domain.append(('device_id', '=', device_id))
        elif fcm_token:
            domain.append(('fcm_token', '=', fcm_token))
        elif voip_token:
            domain.append(('voip_token', '=', voip_token))

        device = self.search(domain, limit=1)

        vals = {
            'platform': platform,
            'active': True,
            'last_seen': now,
        }
        if device_id:
            vals['device_id'] = device_id
        if fcm_token:
            vals['fcm_token'] = fcm_token
        if voip_token:
            vals['voip_token'] = voip_token

        if device:
            device.write(vals)
        else:
            vals['user_id'] = user_id
            device = self.create(vals)

        _logger.info("[WebRTC Device] Registered %s device for User ID %s", platform, user_id)
        return device

    @api.model
    def _send_call_push(self, partner, call_id, call_type, caller_name, action='incoming'):
        """Send push notification to all active devices of the target partner."""
        devices = self.search([
            ('partner_id', '=', partner.id),
            ('active', '=', True),
        ])
        if not devices:
            _logger.info("[WebRTC Push] No active devices found for Partner %s (ID %s)", partner.name, partner.id)
            return False

        for device in devices:
            try:
                if device.platform == 'android' and device.fcm_token:
                    self._send_fcm_notification(device, call_id, call_type, caller_name, action)
                elif device.platform == 'ios':
                    if action == 'incoming' and device.voip_token:
                        self._send_apns_voip(device, call_id, call_type, caller_name)
                    elif device.fcm_token:
                        self._send_fcm_notification(device, call_id, call_type, caller_name, action)
            except Exception as e:
                _logger.error("[WebRTC Push] Error sending push to device %s: %s", device.id, e)
        return True

    @api.model
    def _get_fcm_v1_access_token(self, service_account_info):
        """Generate Google OAuth2 access token for FCM HTTP v1 using service account private key."""
        try:
            import time
            import base64
            from cryptography.hazmat.primitives import hashes
            from cryptography.hazmat.primitives.asymmetric import padding
            from cryptography.hazmat.primitives.serialization import load_pem_private_key

            now = int(time.time())
            header = {"alg": "RS256", "typ": "JWT"}
            claims = {
                "iss": service_account_info.get("client_email"),
                "scope": "https://www.googleapis.com/auth/firebase.messaging",
                "aud": "https://oauth2.googleapis.com/token",
                "exp": now + 3600,
                "iat": now,
            }

            def b64url(data):
                return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')

            jwt_unsigned = f"{b64url(json.dumps(header).encode('utf-8'))}.{b64url(json.dumps(claims).encode('utf-8'))}"
            private_key = load_pem_private_key(
                service_account_info.get("private_key").encode('utf-8'),
                password=None,
            )
            signature = private_key.sign(
                jwt_unsigned.encode('utf-8'),
                padding.PKCS1v15(),
                hashes.SHA256(),
            )
            jwt_signed = f"{jwt_unsigned}.{b64url(signature)}"

            post_data = urllib.parse.urlencode({
                'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion': jwt_signed,
            }).encode('utf-8')

            req = urllib.request.Request(
                'https://oauth2.googleapis.com/token',
                data=post_data,
                headers={'Content-Type': 'application/x-www-form-urlencoded'},
                method='POST',
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                result = json.loads(resp.read().decode('utf-8'))
                return result.get('access_token')
        except Exception as e:
            _logger.error("[WebRTC FCM] Failed to get OAuth2 token: %s", e)
            return None

    @api.model
    def _send_fcm_notification(self, device, call_id, call_type, caller_name, action):
        """Send high-priority FCM message (supports FCM HTTP v1 and legacy fallback)."""
        get_param = self.env['ir.config_parameter'].sudo().get_param
        sa_json_str = get_param('webrtc_call.fcm_service_account_json')
        
        # 1. FCM HTTP v1 via Service Account
        if sa_json_str:
            try:
                sa_info = json.loads(sa_json_str)
                project_id = sa_info.get('project_id')
                token = self._get_fcm_v1_access_token(sa_info)
                if token and project_id:
                    v1_url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
                    v1_payload = {
                        "message": {
                            "token": device.fcm_token,
                            "data": {
                                "call_id": str(call_id),
                                "call_type": str(call_type),
                                "caller_name": str(caller_name),
                                "action": str(action),
                                "timestamp": datetime.utcnow().isoformat(),
                            },
                            "android": {
                                "priority": "high",
                                "ttl": "45s",
                            },
                        }
                    }
                    req = urllib.request.Request(
                        v1_url,
                        data=json.dumps(v1_payload).encode('utf-8'),
                        headers={
                            'Content-Type': 'application/json',
                            'Authorization': f'Bearer {token}',
                        },
                        method='POST',
                    )
                    with urllib.request.urlopen(req, timeout=8) as resp:
                        _logger.info("[WebRTC FCM v1] Sent successfully to device %s: %s", device.id, resp.read().decode())
                    return
            except Exception as e:
                _logger.error("[WebRTC FCM v1] Error sending v1 push: %s", e)

        # 2. Legacy FCM HTTP Fallback
        fcm_api_key = get_param('webrtc_call.fcm_server_key')
        if not fcm_api_key:
            _logger.debug(
                "[WebRTC FCM] No FCM credentials configured in 'webrtc_call.fcm_service_account_json' or 'webrtc_call.fcm_server_key'."
            )
            return

        payload = {
            'to': device.fcm_token,
            'priority': 'high',
            'content_available': True,
            'data': {
                'call_id': str(call_id),
                'call_type': call_type,
                'caller_name': caller_name,
                'action': action,
                'timestamp': datetime.utcnow().isoformat(),
            },
        }

        req = urllib.request.Request(
            'https://fcm.googleapis.com/fcm/send',
            data=json.dumps(payload).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'key={fcm_api_key}',
            },
            method='POST',
        )
        try:
            with urllib.request.urlopen(req, timeout=5) as response:
                _logger.info("[WebRTC FCM Legacy] Push sent: %s", response.read().decode('utf-8'))
        except Exception as e:
            _logger.error("[WebRTC FCM Legacy] Failed to dispatch push: %s", e)

    @api.model
    def _send_apns_voip(self, device, call_id, call_type, caller_name):
        """Send APNs VoIP push notification (PushKit) using HTTP/2 token-based authentication."""
        get_param = self.env['ir.config_parameter'].sudo().get_param
        key_id = get_param('webrtc_call.apns_key_id')
        team_id = get_param('webrtc_call.apns_team_id')
        bundle_id = get_param('webrtc_call.apns_bundle_id')  # e.g. com.example.chatOdoo
        private_key_p8 = get_param('webrtc_call.apns_private_key')
        use_sandbox = get_param('webrtc_call.apns_sandbox', 'True').lower() in ('true', '1')

        if not (key_id and team_id and bundle_id and private_key_p8):
            _logger.info(
                "[WebRTC APNs] APNs credentials not configured (key_id, team_id, bundle_id, private_key). Skipping VoIP push."
            )
            return

        try:
            import time
            import base64
            from cryptography.hazmat.primitives import hashes
            from cryptography.hazmat.primitives.asymmetric import ec

            # 1. Generate ES256 JWT for APNs
            now = int(time.time())
            header = {"alg": "ES256", "kid": key_id}
            claims = {"iss": team_id, "iat": now}

            def b64url(data):
                return base64.urlsafe_b64encode(data).decode('utf-8').rstrip('=')

            jwt_unsigned = f"{b64url(json.dumps(header).encode('utf-8'))}.{b64url(json.dumps(claims).encode('utf-8'))}"
            from cryptography.hazmat.primitives.serialization import load_pem_private_key
            ec_key = load_pem_private_key(private_key_p8.encode('utf-8'), password=None)
            signature = ec_key.sign(jwt_unsigned.encode('utf-8'), ec.ECDSA(hashes.SHA256()))
            jwt_token = f"{jwt_unsigned}.{b64url(signature)}"

            # 2. VoIP push requires .voip appended to bundle ID
            apns_topic = f"{bundle_id}.voip"
            host = "api.sandbox.push.apple.com" if use_sandbox else "api.push.apple.com"
            url = f"https://{host}/3/device/{device.voip_token}"

            body = json.dumps({
                "aps": {},
                "call_id": str(call_id),
                "call_type": call_type,
                "caller_name": caller_name,
                "handle": caller_name,
            }).encode('utf-8')

            # Use httpx for HTTP/2 if available, else urllib
            try:
                import httpx
                headers = {
                    "authorization": f"bearer {jwt_token}",
                    "apns-topic": apns_topic,
                    "apns-push-type": "voip",
                    "apns-priority": "10",
                    "apns-expiration": "0",
                }
                with httpx.Client(http2=True, timeout=10.0) as client:
                    resp = client.post(url, content=body, headers=headers)
                    _logger.info("[WebRTC APNs] Status %s: %s", resp.status_code, resp.text)
            except ImportError:
                _logger.warning("[WebRTC APNs] httpx with HTTP/2 not installed. PushKit requires HTTP/2.")
        except Exception as e:
            _logger.error("[WebRTC APNs] Failed to send APNs VoIP push: %s", e)
