import 'common.just'

set working-directory := ".."

[group('Config')]
[no-cd]
provision *args:
    @echo "⚙️  Delegating provision to openwrt-config..."
    cd {{quote(ROOT / 'openwrt-config')}} && just provision {{args}}

[group('Config')]
[no-cd]
verify:
    @echo "🔍 Verifying OpenWrt configuration..."
    @cd {{quote(ROOT / 'openwrt-config')}} && just verify

[group('Config')]
[no-cd]
ping:
    @echo "📡 Pinging OpenWrt routers..."
    @cd {{quote(ROOT / 'openwrt-config')}} && just ping

[group('Config')]
[no-cd]
list-hosts:
    @echo "🖥️ Available Ansible Hosts:"
    @cd {{quote(ROOT / 'openwrt-config')}} && just list-hosts
