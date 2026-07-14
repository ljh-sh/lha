/* MinGW builds: <unistd.h> doesn't declare `symlink()` (no _WIN32_WINNT
 * level reliably reveals it on GitHub Actions runners), but upstream's
 * lhext.c calls it unconditionally. Stub it here as a function-like
 * macro that always evaluates to `0-1` (= -1 numerically) so every
 *   l_code = symlink(realname, name);
 * becomes
 *   l_code = 0-1;
 * which compiles cleanly. Upstream's existing fall-through
 * (make_parent_path + retry + unlink on failure) handles the -1 path,
 * matching what lha-test14 already assumes for MinGW ("no symlink
 * support on DJGPP/MinGW").
 *
 * We can't pass `-Dsymlink(real,name)=0-1` via CPPFLAGS env because
 * `/bin/sh` (the make recipe interpreter) parses `(real,name)` as a
 * subshell and rejects the rule before exec'ing gcc. Hiding the macro
 * in a header sidesteps that.
 */
#ifndef LHA_NO_SYMLINK_H
#define LHA_NO_SYMLINK_H
#define symlink(real, name) 0 - 1
#endif
