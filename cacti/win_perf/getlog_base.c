/*****************************************************************************
*
* Getlog base library
*
* License: GPL
* Copyright (c) 2009 Thomas Guyot-Sionnest <tguyot@gmail.com>
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
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>


/* Get the first line of the file... easy stuff */
char *get_head(int log) {
	char readbuf[READ_CHNK];
	int read_sz;
	char *buf = NULL;
	int buf_sz = 0;
	char *tmp = NULL;

	/* Make sure we're at the beginning */
	lseek(log, 0, SEEK_SET);

	/* Loop until we get a newline */
	while ((read_sz = read(log, readbuf, READ_CHNK)) > 0) {
		if ((buf = realloc(buf, buf_sz+read_sz)) == NULL) {
			fprintf(stderr, "malloc failed in get_head()\n");
			exit(3);
		}
		memcpy(buf+buf_sz, readbuf, read_sz);
		buf_sz += read_sz;

		/* Terminate buf as a string if we reached end of line */
	if ((tmp = memchr(buf, '\n', buf_sz)) != NULL) {
			if (tmp[-1] == '\r') tmp--;
			//tmp++; /* keep newline?  */
			tmp[0] = '\0';
			break;
		}
		if (buf_sz >= MAX_READ) break; /* endless line? */
	}
	if (read_sz == -1) {
		perror("read");
		exit(3);
	}

	/* return whatever line de got, or NULL */
	if (tmp) {
#ifdef MALLOC_FREE
		tmp = strdup(buf);
		free(buf);
		buf = tmp;
#endif
		return strdup(buf);
	}
	return NULL;
}

/* Get the last line of the file, reading backwards to make this quick on
 * large log files. */
char *get_tail(int log) {
	char readbuf[READ_CHNK];
	int read_sz;
	char *buf = NULL;
	int buf_sz = 0;
	char *tmp1=NULL, *tmp2=NULL;
	off_t length, start;
	struct stat sb;

	if (fstat(log, &sb) == -1) {
		perror("fstat");
		exit(3);
	}
	length = sb.st_size; /* Size in bytes */

	/* Try to read up to READ_CHNK bytes at time, but make sure we read at
	 * 512-bytes boundaries. THIS IS TRICKY, don't change this unless you
	 * know what you're doing! */
	start = (length / 512) * 512;
	if (start >= READ_CHNK && start == length) {
		start -= READ_CHNK;
	} else if (start >= READ_CHNK) {
		start -= READ_CHNK - 512;
	} else {
		start = 0;
	}

	/* Set our position and start reading */
	lseek(log, start, SEEK_SET);
	while ((read_sz = read(log, readbuf, READ_CHNK)) > 0) {
		if ((buf = realloc(buf, buf_sz+read_sz)) == NULL) {
			fprintf(stderr, "malloc failed in get_tail()\n");
			exit(3);
		}

		/* Prepend to buffer - straight memcpy() if memory don't overlap */
		if (buf_sz)
			memmove(buf+read_sz, buf, buf_sz);
		memcpy(buf, readbuf, read_sz);
		buf_sz += read_sz;

		/* Terminate buf as a string if we got a full line */
		if ((tmp1 = memchr(buf, '\n', buf_sz)) != NULL && tmp1 != buf+buf_sz-1) {

			/* Make sure we got the last line */
			while ((tmp2 = memchr(tmp1+1, '\n', buf_sz-(tmp1-buf)-1)) != NULL) {
				if (tmp2 != buf+buf_sz-1) {
					tmp1 = tmp2;
					continue;
				}
				/* terminate tmp2 such as tmp1 becomes a string */
				break;
			}
			if (tmp2) {
				if (tmp2[-1] == '\r') tmp2--;
				tmp2[0] = '\0';
				tmp1++; /* get past first '\n' */
				break;
			}
		}

		if (buf_sz >= MAX_READ) break; /* endless line? */
		if ((start -= READ_CHNK) < 0) break;
		lseek(log, start, SEEK_SET);
	}

	/* Return the last line if we got one */
	if (tmp1 && tmp2 && tmp2 - tmp1 > 0) {
#ifdef MALLOC_FREE
		tmp2 = strdup(tmp1);
		free(buf);
		tmp1 = tmp2;
#endif
		return strdup(tmp1);
	}
	return NULL;
}

/* Return position of index `colname` on `line`. */
int find_index(const char *colname, char *line) {
	char *col;
	int i = 0;

	while (line && (col = subst_col(0, &line)) != NULL) {
		/* Skip over the server name (\\name) */
		col = strchr(col+3, '\\');
		if (strcmp(col, colname) == 0) return i;
		i++;
	}
	return -1;
}

/*
 * Fetch the column indicated by colnum and remove the scanned part from
 * lineref (this allow faster scanning by find_index() ).
 * NOTE: CSV does not require delimiters on numeric values; but since Windows
 *       doesn't do that anyways it's not supported here. Could be easy to add
 *       though...
 */
char *subst_col(int colnum, char **lineref) {
	char *col=NULL, *delim;
	int i;

	for (i=0; i <= colnum; i++) {
		delim = strchr(*lineref, ',');

		if (delim == NULL) { /* this is the last column? */
			col = strdup(*lineref);
			/* Possible infinite loop is you leave data in there ?*/
			//*lineref = NULL;
		} else {
			col = malloc(delim-*lineref+1);
			strncpy(col, *lineref, delim-*lineref);
			col[delim-*lineref] = '\0';
		}
		/* Look for starting and ending double-quotes... */
		if (col[0] != '"' || col[strlen(col)] != '"') {
			/* The field isn't properly delimited; try next comma and hope for the best */
			if (!delim)
				return NULL;
		}
		*lineref = delim + 1;

		if (i == colnum) {
			/* We're done, extract the current column */
			/* remove quotes... */
			col++;
			col[strlen(col)-1] = '\0';
			break;
		}
#ifdef MALLOC_FREE
		free(col);
#else
		col = NULL;
#endif
	}
	return col;
}

/* Date string to time diff. Ex. string: "01/22/2008 07:49:19.798" */
int datediff(const char *datestr) {
	char *array[7];
	char *tmp;
	char dup[25];
	int i, month, day, year, hour, min, sec;
	time_t *now=NULL;
	struct tm *tmnow;

	if (strlen(datestr) != 23)
		return -1;

	strncpy(dup, datestr, 24);
	dup[23] = dup[24] = '\0';
	tmp = array[0] = dup;

	/* Loop over the string and replace separators with NULLs */
	for (i=1; i<=6; i++) {
		if ((tmp = strpbrk(tmp, "/ :.")) == NULL)
			return -1;

		tmp[0] = '\0';
		tmp++;
		array[i] = tmp;
	}

	month = myatoi(array[0]);
	day = myatoi(array[1]);
	year = myatoi(array[2]);
	hour = myatoi(array[3]);
	min = myatoi(array[4]);
	sec = myatoi(array[5]);

	*now = time(NULL);
	tmnow = localtime(now);

	tmnow->tm_mon++;
	tmnow->tm_year += 1900;

	/* Seconds out from Google Calculator. Those are rounded averages; we
	 * don't care about precision as we really shouldn't need to exceed one
	 * day. We care about correctness though (i.e. same date last month is
	 * NOT correct). */
	return  (tmnow->tm_year-year)*31556926
	       +(tmnow->tm_mon-month)*2629744
	       +(tmnow->tm_mday-day)*86400
	       +(tmnow->tm_hour-hour)*3600
	       +(tmnow->tm_min-min)*60
	       +(tmnow->tm_sec-sec);
}

/* like atoi with error checking */
int myatoi(const char *num) {
	char *endptr;
	long val;

	errno = 0;
	val = strtol(num, &endptr, 10);

	if ((errno == ERANGE && (val == LONG_MAX || val == LONG_MIN)) || (errno != 0 && val == 0)) {
		perror("strtol");
		exit(3);
	}
	if (val >= INT_MAX || val < 0) {
		fprintf(stderr, "Number our of bounds\n");
		exit(3);
	}

	if (endptr == num) {
		fprintf(stderr, "No digits were found\n");
		exit(EXIT_FAILURE);
	}

	return (int)val;
}

