/* getlog.h - common parameters for getlog */

/* ***** CONFIG ***** */

/* This is the place where logs files are dropped */
#define LOG_PATH "/var/log/cacti"

/* If last line's timestamp is older that this (seconds), no data will be
 * returned. Additionally, if STALL_CMD is defined it will be run. Set it
 * to 0 to avoid this check. */
#define MAX_AGE 120 /* 2 minutes */

/* This is a script that will be run if the log is stall for more than 
 * MAX_AGE seconds (It's up to you to make good use of this). Have no
 * effect if MAX_AGE isn't positive. The original idea was to have a Nagios
 * event handler restart the counter when stall (Implement it the way you
 * like though). */
#define STALL_CMD "/usr/local/nagios/libexec/eventhandlers/notify_stall_counter $ARGV[0]"

/* This is the maximum read size for each read. Optimal performance can be
 * obtained by setting this to the smallest number higher than your usual
 * line length. THIS MUST BE A 512-BYTES MULTIPLE!! I.e. 512, 1024, 8192, 8704
 * are all valid numbers.
 *
 * The current implementation limit this value to 32256 */
#define READ_CHNK 512 * 2 /* 1024 bytes */

/* Maximum buffered read size (Will stop reading lines longer than this!) */
#define MAX_READ 1024 * 512 /* 512KiB */

/* Define MALLOC_FREE if you want to free all dynamically allocated  memory.
 * Normally, the OS does a better job at is when the process exits */
/* #define MALLOC_FREE */


/* ***** PROTOTYPES ***** */

char *get_head(int);
char *get_tail(int);
int find_index(const char *, char *);
char *subst_col(int, char **);
int datediff(const char*);
int myatoi(const char*);


/* End of getlog.h */

