# -*- coding: utf-8 -*-
from datetime import datetime, timedelta
import logging
from odoo import models, fields, api, _
from odoo.exceptions import UserError, AccessError

_logger = logging.getLogger(__name__)

CALL_STATES = [
    ('ringing', 'Ringing'),
    ('accepted', 'Accepted'),
    ('rejected', 'Rejected'),
    ('missed', 'Missed'),
    ('ended', 'Ended'),
    ('busy', 'Busy'),
    ('failed', 'Failed'),
    ('cancelled', 'Cancelled'),
]

CALL_TYPES = [
    ('audio', 'Audio Call'),
    ('video', 'Video Call'),
]


class WebrtcCall(models.Model):
    _name = 'webrtc.call'
    _description = 'WebRTC 1-to-1 Call'
    _order = 'start_time desc, id desc'
    _rec_name = 'display_name'

    caller_id = fields.Many2one(
        'res.partner',
        string='Caller',
        required=True,
        index=True,
        ondelete='cascade',
    )
    caller_name = fields.Char(related='caller_id.name', string='Caller Name', readonly=True)
    caller_image = fields.Binary(related='caller_id.avatar_128', string='Caller Avatar', readonly=True)

    callee_id = fields.Many2one(
        'res.partner',
        string='Callee',
        required=True,
        index=True,
        ondelete='cascade',
    )
    callee_name = fields.Char(related='callee_id.name', string='Callee Name', readonly=True)
    callee_image = fields.Binary(related='callee_id.avatar_128', string='Callee Avatar', readonly=True)

    call_type = fields.Selection(
        CALL_TYPES,
        string='Call Type',
        required=True,
        default='audio',
        index=True,
    )
    state = fields.Selection(
        CALL_STATES,
        string='State',
        required=True,
        default='ringing',
        index=True,
    )

    start_time = fields.Datetime(
        string='Call Initiated',
        default=fields.Datetime.now,
        required=True,
        index=True,
    )
    answer_time = fields.Datetime(string='Call Answered')
    end_time = fields.Datetime(string='Call Ended')
    duration = fields.Integer(
        string='Duration (sec)',
        compute='_compute_duration',
        store=True,
        help='Call duration in seconds from answer to end.',
    )
    duration_formatted = fields.Char(
        string='Duration',
        compute='_compute_duration_formatted',
        help='Human-readable call duration (MM:SS or HH:MM:SS).',
    )
    end_reason = fields.Char(string='End Reason', help='e.g., normal, rejected, timeout, network_failure')

    display_name = fields.Char(string='Call Reference', compute='_compute_display_name', store=True)

    @api.depends('caller_id', 'callee_id', 'call_type', 'start_time')
    def _compute_display_name(self):
        for record in self:
            c_type = 'Video' if record.call_type == 'video' else 'Audio'
            caller = record.caller_id.name or 'Unknown'
            callee = record.callee_id.name or 'Unknown'
            record.display_name = f"{c_type} Call: {caller} → {callee}"

    @api.depends('answer_time', 'end_time', 'state')
    def _compute_duration(self):
        for record in self:
            if record.answer_time and record.end_time and record.state == 'ended':
                delta = record.end_time - record.answer_time
                record.duration = max(0, int(delta.total_seconds()))
            else:
                record.duration = 0

    @api.depends('duration')
    def _compute_duration_formatted(self):
        for record in self:
            d = record.duration or 0
            hours, remainder = divmod(d, 3600)
            minutes, seconds = divmod(remainder, 60)
            if hours > 0:
                record.duration_formatted = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
            else:
                record.duration_formatted = f"{minutes:02d}:{seconds:02d}"

    def _to_dict(self):
        """Serialize call details for API / Bus transport."""
        self.ensure_one()
        return {
            'id': self.id,
            'call_type': self.call_type,
            'state': self.state,
            'start_time': fields.Datetime.to_string(self.start_time),
            'answer_time': fields.Datetime.to_string(self.answer_time) if self.answer_time else None,
            'end_time': fields.Datetime.to_string(self.end_time) if self.end_time else None,
            'duration': self.duration,
            'duration_formatted': self.duration_formatted,
            'end_reason': self.end_reason,
            'caller': {
                'partner_id': self.caller_id.id,
                'name': self.caller_id.name,
                'email': self.caller_id.email,
            },
            'callee': {
                'partner_id': self.callee_id.id,
                'name': self.callee_id.name,
                'email': self.callee_id.email,
            },
        }

    def _send_bus_event(self, target_partner, event_type, extra_data=None):
        """Send WebRTC call notification via Odoo 18 bus.bus."""
        self.ensure_one()
        payload = {
            'event': event_type,
            'call': self._to_dict(),
        }
        if extra_data:
            payload.update(extra_data)

        _logger.info(
            "[WebRTC Call] Sending bus event '%s' for Call ID %s to Partner ID %s (%s)",
            event_type,
            self.id,
            target_partner.id,
            target_partner.name,
        )
        self.env['bus.bus']._sendone(target_partner, 'webrtc_call', payload)

    def action_accept(self):
        self.ensure_one()
        if self.state != 'ringing':
            raise UserError(_("Call is no longer in ringing state (current: %s).") % self.state)
        now = fields.Datetime.now()
        self.write({
            'state': 'accepted',
            'answer_time': now,
        })
        self._send_bus_event(self.caller_id, 'call_accepted')
        return True

    def action_reject(self, reason='rejected'):
        self.ensure_one()
        if self.state not in ('ringing', 'busy'):
            return False
        now = fields.Datetime.now()
        self.write({
            'state': reason if reason in ('rejected', 'busy') else 'rejected',
            'end_time': now,
            'end_reason': reason,
        })
        self._send_bus_event(self.caller_id, 'call_rejected', {'reason': reason})
        return True

    def action_cancel(self):
        self.ensure_one()
        if self.state != 'ringing':
            return False
        now = fields.Datetime.now()
        self.write({
            'state': 'cancelled',
            'end_time': now,
            'end_reason': 'caller_cancelled',
        })
        self._send_bus_event(self.callee_id, 'call_cancelled')
        return True

    def action_end(self, reason='normal'):
        self.ensure_one()
        if self.state in ('ended', 'cancelled', 'rejected', 'missed', 'failed'):
            return False
        now = fields.Datetime.now()
        self.write({
            'state': 'ended',
            'end_time': now,
            'end_reason': reason,
        })
        # Notify the other party depending on who triggered the end
        current_partner = self.env.user.partner_id
        other_partner = self.callee_id if current_partner == self.caller_id else self.caller_id
        self._send_bus_event(other_partner, 'call_ended', {'reason': reason})
        return True

    def action_timeout(self):
        self.ensure_one()
        if self.state != 'ringing':
            return False
        now = fields.Datetime.now()
        self.write({
            'state': 'missed',
            'end_time': now,
            'end_reason': 'timeout_no_answer',
        })
        self._send_bus_event(self.caller_id, 'call_missed', {'reason': 'timeout'})
        self._send_bus_event(self.callee_id, 'call_missed', {'reason': 'timeout'})
        # Also trigger missed call push notification
        self.env['webrtc.device']._send_call_push(
            partner=self.callee_id,
            call_id=self.id,
            call_type=self.call_type,
            caller_name=self.caller_id.name,
            action='missed',
        )
        return True

    @api.model
    def _cron_check_missed_calls(self):
        """Cron job: auto-terminate calls ringing > 45 seconds."""
        timeout_threshold = fields.Datetime.now() - timedelta(seconds=45)
        stale_calls = self.search([
            ('state', '=', 'ringing'),
            ('start_time', '<=', timeout_threshold),
        ])
        _logger.info("[WebRTC Cron] Checking stale ringing calls: found %s", len(stale_calls))
        for call in stale_calls:
            try:
                call.action_timeout()
            except Exception as e:
                _logger.error("[WebRTC Cron] Error timing out Call ID %s: %s", call.id, e)
