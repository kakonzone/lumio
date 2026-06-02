# Source once (add to ~/.bashrc):  source /path/to/lumio/scripts/flutter_env.sh
# After that, plain `flutter run` in this repo auto-loads secrets.json.
flutter() {
  if [[ -f "${PWD}/secrets.json" ]]; then
    case "${1:-}" in
      run|build|test|drive|install)
        command flutter "$@" --dart-define-from-file="${PWD}/secrets.json"
        return $?
        ;;
    esac
  fi
  command flutter "$@"
}
