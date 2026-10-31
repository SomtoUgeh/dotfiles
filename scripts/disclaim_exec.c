// Run a program as its own TCC responsible process, so macOS privacy grants (Accessibility,
// Screen Recording) are checked against that program and not against whoever launched it.
//
// The Executor stdio bridge is a launchd job, so without this every child it starts inherits the
// bridge's Node binary as its responsible process, and a grant for agent-desktop would have to be
// given to Node itself (and with it to every server behind the bridge).
//
// Build: xcrun clang -O2 -Wall -o ~/.local/share/executor-local-tools/bin/disclaim-exec scripts/disclaim_exec.c
// Usage: disclaim-exec /absolute/program [args...]   (stdio is inherited; exit status is passed through)
#include <errno.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>

extern char **environ;
// Private libsystem call (macOS 10.14+), also used by Chromium and LLDB for the same purpose.
int responsibility_spawnattrs_setdisclaim(posix_spawnattr_t *attrs, int disclaim);

static volatile pid_t child = 0;

static void forward(int sig) {
  if (child > 0) kill(child, sig);
}

int main(int argc, char **argv) {
  if (argc < 2 || argv[1][0] != '/') {
    fprintf(stderr, "usage: disclaim-exec /absolute/program [args...]\n");
    return 64;
  }
  posix_spawnattr_t attrs;
  if (posix_spawnattr_init(&attrs) != 0 || responsibility_spawnattrs_setdisclaim(&attrs, 1) != 0) {
    fprintf(stderr, "disclaim-exec: cannot set responsibility disclaim\n");
    return 70;
  }
  struct sigaction sa;
  memset(&sa, 0, sizeof sa);
  sa.sa_handler = forward;
  sigaction(SIGTERM, &sa, NULL);
  sigaction(SIGINT, &sa, NULL);
  sigaction(SIGHUP, &sa, NULL);

  pid_t pid;
  int rc = posix_spawn(&pid, argv[1], NULL, &attrs, argv + 1, environ);
  posix_spawnattr_destroy(&attrs);
  if (rc != 0) {
    fprintf(stderr, "disclaim-exec: cannot start %s: %s\n", argv[1], strerror(rc));
    return 127;
  }
  child = pid;
  int status;
  while (waitpid(pid, &status, 0) < 0) {
    if (errno != EINTR) return 70;
  }
  if (WIFEXITED(status)) return WEXITSTATUS(status);
  return 128 + WTERMSIG(status);
}
