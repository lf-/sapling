# shellcheck disable=SC2148
# Make the test use chg if possible

if [ -x "$RUNTESTDIR/../contrib/chg/chg" ] && [ -z "$CHGHG" ]; then
  CHGHG="${HG:-hg}"
  export CHGHG
  # shellcheck disable=SC2139
  alias hg="${CHG:-chg}"
fi
