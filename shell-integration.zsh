# cloudless-proxy shell integration
#
# Source this from your ~/.zshrc (or ~/.bashrc) to drive the proxy from any
# directory without cd-ing into the repo or `source activate` by hand:
#
#     CLOUDLESS_PROXY_PATH="$HOME/code/ql4b/cloudless/cloudless-proxy"
#     source "$CLOUDLESS_PROXY_PATH/shell-integration.zsh"
#
# Then: proxy_up / proxy_status / proxy_env / proxy_scale_down / ...

# Path to your clone. Override before sourcing if it lives elsewhere.
: "${CLOUDLESS_PROXY_PATH:=$HOME/code/ql4b/cloudless/cloudless-proxy}"

# Run a `proxy` subcommand in a SUBSHELL so the cd + `source activate`
# (which prepends to PATH) stay contained and never leak into your
# interactive shell. Use for actions that don't need to modify your shell.
_proxy() {
  ( cd "$CLOUDLESS_PROXY_PATH" && source ./activate && proxy "$@" )
}

proxy_up()         { _proxy up "$@"; }
proxy_down()       { _proxy down "$@"; }
proxy_recreate()   { _proxy recreate "$@"; }
proxy_status()     { _proxy status "$@"; }
proxy_scale_up()   { _proxy scale-up "$@"; }
proxy_scale_down() { _proxy scale-down "$@"; }
proxy_url()        { _proxy url "$@"; }
proxy_test()       { _proxy test "$@"; }

# Drop into the activated repo. This intentionally runs in your CURRENT
# shell (no subshell) so you stay cd'd in with bin/ on PATH.
cloudless_proxy() {
  cd "$CLOUDLESS_PROXY_PATH" && source ./activate
}

# Export HTTP_PROXY et al into your CURRENT shell. Must NOT use a subshell —
# it has to mutate this shell. `proxy env` resolves the live instance and
# prints `export ...` lines; we capture them from a subshell (so .env/PATH
# side-effects stay contained) and eval them here. In v3 the proxy IP is
# resolved live by tag, so this only works when an instance is running.
proxy_env() {
  local exports
  exports="$( cd "$CLOUDLESS_PROXY_PATH" && source ./activate && proxy env )" || {
    echo "proxy_env: no running proxy (try 'proxy_up' or 'proxy_scale_up')" >&2
    return 1
  }
  eval "$exports"
}

# Run mitmproxy locally, forwarding upstream through the cloud proxy.
proxy_mitm() {
  local port="${1:-8080}"
  shift 2>/dev/null
  proxy_env || return 1
  mitmproxy \
    --mode "upstream:$HTTP_PROXY" \
    --listen-host 127.0.0.1 \
    --listen-port "$port" \
    --ssl-insecure \
    "$@"
}

# Launch a browser pointed at the local mitmproxy listener.
proxy_mitm_browser() {
  local port="${1:-8080}"
  chrome-canary --proxy-server="http://127.0.0.1:$port"
}
