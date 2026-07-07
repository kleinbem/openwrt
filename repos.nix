# Sub-repo manifest for the OpenWrt meta-workspace.
#
# Replaces .gitmodules — meta no longer pins specific commits of each
# sub-repo. Each one is an independent git+jj repo cloned side-by-side
# (same pattern as the nix meta-workspace).
#
# To clone all sub-repos into the workspace, run `just jj::bootstrap`.
{
  openwrt-builder = "git@github.com:kleinbem/openwrt-builder.git";
  openwrt-config = "git@github.com:kleinbem/openwrt-config.git";
  openwrt-secrets = "git@github.com:kleinbem/openwrt-secrets.git";
}
