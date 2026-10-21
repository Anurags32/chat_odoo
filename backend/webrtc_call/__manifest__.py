# -*- coding: utf-8 -*-
{
    'name': 'WebRTC 1-to-1 Audio & Video Calling',
    'version': '18.0.1.0.0',
    'category': 'Discuss',
    'summary': 'Peer-to-peer WebRTC Audio & Video calls using Odoo 18 bus signaling',
    'description': """
WebRTC 1-to-1 Audio and Video Calling for Flutter
=================================================
- Real-time signaling via Odoo 18 Bus (`/websocket`, bus.bus)
- Native background push support (FCM HTTP v1 + APNs VoIP PushKit)
- Coturn TURN server integration with time-limited HMAC credentials
- Full call state lifecycle (ringing, accepted, rejected, busy, missed, ended, cancelled)
- Automated missed call cron job
- Secure record rules (users only access their own calls)
    """,
    'author': 'NSPL Team',
    'website': 'https://github.com/Anurags32/chat_odoo',
    'license': 'LGPL-3',
    'depends': [
        'base',
        'bus',
        'mail',
    ],
    'data': [
        'security/webrtc_call_security.xml',
        'security/ir.model.access.csv',
        'data/ir_cron.xml',
        'views/webrtc_call_views.xml',
        'views/webrtc_device_views.xml',
        'views/menus.xml',
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
}
