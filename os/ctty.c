/*
 * ctty — tiny getty replacement for Fundray Linux.
 *
 * Usage: ctty /dev/ttyN
 *
 * Opens the given terminal, makes it the controlling terminal of a new
 * session, wires it to stdin/stdout/stderr and execs /bin/sh.
 * busybox cttyhack cannot be used here because it ignores its stdin and
 * guesses the console from /sys/class/tty/console/active (always picking
 * the last console= boot parameter), which breaks multi-console setups.
 */
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

int main(int argc, char **argv)
{
	int fd;

	if (argc != 2)
		return 2;

	fd = open(argv[1], O_RDWR);
	if (fd < 0)
		return 1;

	setsid();
	ioctl(fd, TIOCSCTTY, 0);
	dup2(fd, 0);
	dup2(fd, 1);
	dup2(fd, 2);
	if (fd > 2)
		close(fd);

	{
		char *sh[] = { "/bin/sh", (char *)0 };
		execv("/bin/sh", sh);
	}
	return 1;
}
