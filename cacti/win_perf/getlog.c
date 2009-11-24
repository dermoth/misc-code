/*****************************************************************************
*
* Getlog - Windows CSV Performance Data Log Parser for Cacti
*
* Version v.0.9
*
* License: GPL
* Copyright (c) 2009 Thomas Guyot-Sionnest <tguyot@gmail.com>
*
* This program reads Windows performance logs (normally saved to a samba share)
* and returns the last value for a given counter in a format suitable for
* Cacti.
*
* Configuration is done statically - see below (~ 2 pages down) for options.
*
* Usage: getlog <servername> <instance>
*        getlog <servername> list
* Ex: ./getlog SRV6 '\LogicalDisk(C:)\% Disk Time'
*     ./getlog SRV6 "\\LogicalDisk(C:)\\% Disk Time"
* Output: Cacti data format (or nothing). Errors goes to STDERR.
*
* Log files should be saved under LOG_PATH and named "<hostname>.csv"
* Everything is CaSe-SenSITive!
*
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
*****************************************************************************/

#include "getlog.h"
#include "getlog_base.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/* Error handler for getlog_base */
void getlog_exit(char *message) {
	fprintf(stderr, "%s\n", message);
	exit(1);
}

int main(int argc, char **argv, char **envp) {
	char *log = NULL;
	char *header, *last, *col, *datestr, *value;
	int fd, idx, diff;

	if (argc != 3) {
		fprintf(stderr, "Usage: %s <servername> <instance>\n", argv[0]);
		fprintf(stderr, "       %s <servername> list\n", argv[0]);
		exit(1);
	}

	/* Set externs to be used by getlog_base */
	read_chnk = READ_CHNK;
	max_read = MAX_READ;
	getlog_err = &getlog_exit;

	/* Open the log and get the first and last lines */
	log = malloc(strlen(LOG_PATH)+strlen(argv[1])+6);
	sprintf(log, "%s/%s.csv", LOG_PATH, argv[1]);

	if ((fd = open(log, O_RDONLY)) == -1) {
		perror("open");
		exit(1);
	}
#ifdef MALLOC_FREE
	free(log);
#endif

	if ((header = get_head(fd)) == NULL) {
		fprintf(stderr, "Failed to read first line!\n");
		exit(1);
	}
	if ((last = get_tail(fd)) == NULL) {
		fprintf(stderr, "Failed to read last line!\n");
		exit(1);
	}
	close(fd);

	/* Strip the first column (we'll do the same to get the date field) */
	subst_col(0, &header);

	if (strcmp(argv[2], "list") == 0) {
		printf("Available counters:\n");
		while ((col = subst_col(0, &header)) != NULL) {
			col+= 2;
			if ((col = strchr(col, '\\')) == NULL) {
				fprintf(stderr, "Invalid column header\n");
				exit(1);
			}
			printf("%s\n", col);
#ifdef MALLOC_FREE
			free(col);
#endif
		}
		exit(0);
	}

	/* Check the date */
	datestr = subst_col(0, &last);
#ifdef MAX_AGE
	if (MAX_AGE > 0) {
		if ((diff = datediff(datestr)) == -1) {
			fprintf(stderr, "Couldn't parse date string '%s'\n", datestr);
			exit(1);
		}

		if (diff > MAX_AGE) {
#ifdef STALL_CMD
			/* Run STALL_CMD and exit, but don't block the Cacti poller! */
			if (fork() == 0) {
				char *newargv[] = { STALL_CMD, argv[1], argv[2] };
				execve(STALL_CMD, newargv, envp);
				perror("execve");
				exit(1);
			}
#endif
			exit(0);
		}
	}
#endif

	if ((idx = find_index(argv[2], header)) == -1) {
		fprintf(stderr, "No matching index: '%s'\n", argv[2]);
		exit(1);
	}

	if ((value = subst_col(idx, &last)) == NULL) {
		fprintf(stderr, "Column '%i' not found!\n", idx);
		exit(1);
	}

	printf("%s\n", value);
	exit(0);
}

