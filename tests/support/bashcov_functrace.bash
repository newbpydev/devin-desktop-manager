if [[ "${BASH_XTRACEFD:-}" =~ ^[0-9]+$ && "${BASH_XTRACEFD}" != 19 && \
  -e "/proc/$$/fd/${BASH_XTRACEFD}" ]]; then
  exec 19>&"${BASH_XTRACEFD}"
  BASH_XTRACEFD=19
  export BASH_XTRACEFD
fi
set -T
