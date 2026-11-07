import 'common.just'

set working-directory := ".."

[group('Config')]
[no-cd]
provision *args:
    @echo "⚙️  Delegating provision to openwrt-config..."
    cd {{ROOT}}/openwrt-config && just provision {{args}}

[group('Config')]
[no-cd]
verify:
    @echo "🔍 Verifying OpenWrt configuration..."
    @cd {{ROOT}}/openwrt-config && just verify

[group('Config')]
[no-cd]
ping:
    @echo "📡 Pinging OpenWrt routers..."
    @cd {{ROOT}}/openwrt-config && just ping

[group('Config')]
[no-cd]
list-hosts:
    @echo "🖥️ Available Ansible Hosts:"
    @cd {{ROOT}}/openwrt-config && just list-hosts
