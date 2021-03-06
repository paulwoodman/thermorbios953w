--- wview-5.5.0/./stations/Makefile.am	2009-03-08 01:23:08.000000000 -0600
+++ wview-5.5.0-mods/./stations/Makefile.am	2009-05-14 11:58:48.000000000 -0500
@@ -8,4 +8,5 @@
 	VantagePro \
 	WXT510 \
 	WS-2300 \
-	WMR918
+	WMR918 \
+	BW9xx
--- wview-5.5.0/./stations/BW9xx/bw9xx.h	1969-12-31 18:00:00.000000000 -0600
+++ wview-5.5.0-mods/./stations/BW9xx/bw9xx.h	2009-05-15 09:12:05.000000000 -0500
@@ -0,0 +1,69 @@
+#ifndef INC_bw9xxh
+#define INC_bw9xxh
+/*---------------------------------------------------------------------------
+ 
+  FILENAME:
+        bw9xx.h
+ 
+  PURPOSE:
+        Provide the station simulator interface API and utilities.
+ 
+  REVISION HISTORY:
+        Date            Engineer        Revision        Remarks
+        09/08/2008      R.G. Pike       0               Original
+ 
+  NOTES:
+        
+ 
+  LICENSE:
+        This source code is released for free distribution under the terms 
+        of the GNU General Public License.
+  
+----------------------------------------------------------------------------*/
+
+/*  ... System include files
+*/
+#include <unistd.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <sys/time.h>
+#include <sys/types.h>
+#include <sys/wait.h>
+#include <string.h>
+#include <signal.h>
+#include <fcntl.h>
+#include <termios.h>
+#include <time.h>
+#include <errno.h>
+#include <math.h>
+
+/*  ... Library include files
+*/
+#include <sysdefs.h>
+#include <radtimeUtils.h>
+#include <radmsgLog.h>
+#include <radsysutils.h>
+
+/*  ... Local include files
+*/
+#include <datadefs.h>
+#include <config.h>
+#include <computedData.h>
+#include <daemon.h>
+#include <station.h>
+#include <serial.h>
+#include <ethernet.h>
+
+
+// define simulator interface data here
+typedef struct
+{
+    int             elevation;
+    float           latitude;
+    float           longitude;
+    int             archiveInterval;
+    WV_ACCUM_ID     rainRateAccumulator;    // to compute rain rate
+} BW9XX_IF_DATA;
+
+#endif
+
--- wview-5.5.0/./stations/BW9xx/Makefile.am	1969-12-31 18:00:00.000000000 -0600
+++ wview-5.5.0-mods/./stations/BW9xx/Makefile.am	2009-05-14 12:12:30.000000000 -0500
@@ -0,0 +1,56 @@
+# Makefile - station daemon
+
+# define the executable to be built
+bin_PROGRAMS    = wviewd_bw9xx
+
+# define include directories
+INCLUDES = \
+		-I$(top_srcdir)/common \
+		-I$(top_srcdir)/stations/common \
+		-I$(prefix)/include \
+		-DHOST_IS_BIGENDIAN=@HOST_IS_BIGENDIAN@ \
+		-D_GNU_SOURCE \
+		-DWV_CONFIG_DIR=\"$(prefix)/etc/wview\" \
+		-DWV_RUN_DIR=\"$(prefix)/var/wview\" \
+		-DBUILD_WVIEWD
+
+# define the sources
+wviewd_bw9xx_SOURCES     = \
+		$(top_srcdir)/common/sensor.c \
+		$(top_srcdir)/common/wvutils.c \
+		$(top_srcdir)/common/wvconfig.c \
+		$(top_srcdir)/common/dbsqlite.c \
+		$(top_srcdir)/common/dbsqliteHiLow.c \
+		$(top_srcdir)/common/windAverage.c \
+		$(top_srcdir)/common/emailAlerts.c \
+		$(top_srcdir)/stations/common/computedData.c \
+		$(top_srcdir)/stations/common/daemon.c \
+		$(top_srcdir)/stations/common/station.c \
+		$(top_srcdir)/stations/common/serial.c \
+		$(top_srcdir)/stations/common/ethernet.c \
+		$(top_srcdir)/stations/common/stormRain.c \
+		$(top_srcdir)/stations/common/parser.c \
+		$(top_srcdir)/stations/BW9xx/bw9xx.c \
+		$(top_srcdir)/common/sensor.h \
+		$(top_srcdir)/common/datadefs.h \
+		$(top_srcdir)/common/dbsqlite.h \
+		$(top_srcdir)/common/services.h \
+		$(top_srcdir)/common/sysdefs.h \
+		$(top_srcdir)/common/wvconfig.h \
+		$(top_srcdir)/common/windAverage.h \
+		$(top_srcdir)/common/emailAlerts.h \
+		$(top_srcdir)/common/beaufort.h \
+		$(top_srcdir)/stations/common/computedData.h \
+		$(top_srcdir)/stations/common/daemon.h \
+		$(top_srcdir)/stations/common/station.h \
+		$(top_srcdir)/stations/common/serial.h \
+		$(top_srcdir)/stations/common/ethernet.h \
+		$(top_srcdir)/stations/common/stormRain.h \
+		$(top_srcdir)/stations/common/parser.h \
+		$(top_srcdir)/stations/BW9xx/bw9xx.h
+
+# define libraries
+wviewd_bw9xx_LDADD       = -lc -lm -lrad -lsqlite3
+
+# define library directories
+wviewd_bw9xx_LDFLAGS     = -L/usr/lib -L/usr/local/lib -L$(prefix)/lib
--- wview-5.5.0/./stations/BW9xx/bw9xx.c	1969-12-31 18:00:00.000000000 -0600
+++ wview-5.5.0-mods/./stations/BW9xx/bw9xx.c	2009-05-15 09:12:01.000000000 -0500
@@ -0,0 +1,860 @@
+/*---------------------------------------------------------------------------
+ 
+  FILENAME:
+        bw9xx.c
+ 
+  PURPOSE:
+        Provide the BW9xx interface API and utilities.
+ 
+  REVISION HISTORY:
+        Date            Engineer        Revision        Remarks
+        09/06/2008      R.G. Pike       0               Original
+ 
+  NOTES:
+        
+ 
+  LICENSE:
+        This source code is released for free distribution under the terms 
+        of the GNU General Public License.
+  
+----------------------------------------------------------------------------*/
+
+/*  ... System include files
+*/
+
+/*  ... Library include files
+*/
+
+/*  ... Local include files
+*/
+#include <bw9xx.h>
+#include <sys/types.h>
+#include <sys/socket.h>
+#include <sys/un.h>
+#include <unistd.h>
+#include <stdlib.h>
+#include <stdio.h>
+#include <pthread.h>
+
+/*  ... global memory declarations
+*/
+
+/*  ... local memory
+*/
+
+static BW9XX_IF_DATA bw9xxWorkData;
+static void (*ArchiveIndicator) (ARCHIVE_PKT *newRecord);
+
+static int storeLoopPkt (LOOP_PKT *dest);
+static void *readerThread(void *);
+
+static float MmToInches(int);
+static float CelsiusToFahrenheit(float);
+static float MillibarsToInches(float);
+static float KmhToMph(float);
+
+// Data from the bw9xx that is shared between the thread, which
+// populates this structure, and the stationGetReadings() "callback",
+// whichs hands off the data to the main program.
+//
+// Adding an element to monitor requires additions to three places.
+// 		1. add a variable to update in bw9xx_data
+// 		2. add how to process it in the datums array below
+// 		3. pass the data back in storeLoopPkt()
+// An element can be added to monitor without passing it back
+// to the rest of wviewd (meaning you can skip step 3).
+struct bw9xx_data
+	{
+	float inTemp;
+	float outTemp;
+	float barometer;
+	int inHumidity;
+	int direction;
+	float curWindSpeed;
+	float maxGust;
+	int curRain;
+	int prevRain;
+
+	pthread_mutex_t locker;		// mutex to use when accessing data
+	int dataready;				// when 1, data ready to be read
+	int humidity_is_outside;
+	char *device;
+	};
+
+struct ws9xxd_dataline
+	{
+	char *desc;
+	char *desc_csv;
+	void *value;
+
+	void (*processor)(char *, struct ws9xxd_dataline *);
+	void (*stringtoval)(const char *, void *);
+	void (*prelog)(char *, struct ws9xxd_dataline *);
+	void (*postlog)(char *, struct ws9xxd_dataline *);
+	};
+
+static void processor_cb(char *, struct ws9xxd_dataline *);
+static void prelog_cb(char *, struct ws9xxd_dataline *);
+static void postlog_int_cb(char *, struct ws9xxd_dataline *);
+static void postlog_float_cb(char *, struct ws9xxd_dataline *);
+static void atof_cb(const char *, void *);
+static void atoi_cb(const char *, void *);
+static void increment_cb(const char *, void *);
+
+static struct bw9xx_data weather_data;
+
+static struct ws9xxd_dataline datums[] =
+{
+	{
+	"DATA: Current Outside Temperature: ",	// Description to find
+	",Current,Outside Temperature,",
+		&(weather_data.outTemp),			// Value to change
+		processor_cb,						// callback for change
+											// and loggin
+		atof_cb,							// string to type function
+		NULL,								// log before processing
+											// ex. prelog_cb
+		NULL								// log after processing
+											// ex. postlog_int_cb
+	},
+
+	{
+	"DATA: Date: ",
+	",,Date,",
+		&(weather_data.dataready),
+		processor_cb, increment_cb, NULL, NULL
+	},
+
+	{
+	"DATA: Current Pressure: ",
+	",Current,Pressure,",
+		&(weather_data.barometer),
+		processor_cb, atof_cb, NULL, NULL
+	},
+
+	{
+	"DATA: Current Humidity: ",
+	",Current,Humidity,",
+		&(weather_data.inHumidity),
+		processor_cb, atoi_cb, NULL, NULL
+	},
+
+	{
+	"DATA: Current Inside Temperature: ",
+	",Current,Inside Temperature,",
+		&(weather_data.inTemp),
+		processor_cb, atof_cb, NULL, NULL
+	},
+
+	{
+	"DATA: Wind Direction: ",
+	",,Wind Direction,",
+		&(weather_data.direction),
+		processor_cb, atoi_cb, NULL, NULL
+	},
+
+	{
+	"DATA: Current Wind Speed: ",
+	",Current,Wind Speed,",
+		&(weather_data.curWindSpeed),
+		processor_cb, atof_cb, NULL, NULL
+	},
+
+	{
+	"DATA: Current Wind Gust: ",
+	",Current,Wind Gust,",
+		&(weather_data.maxGust),
+		processor_cb, atof_cb, NULL, NULL
+	},
+
+	{
+	"DATA: Current Rain: ",
+	",Current,Rain,",
+		&(weather_data.curRain),
+		processor_cb, atoi_cb, NULL, NULL
+	},
+
+	// keep last entry NULL - it's how the loop detects the end
+	{
+	NULL,
+		NULL, NULL, NULL, NULL, NULL
+	}
+};
+
+////////////****////****  S T A T I O N   A P I  ****////****////////////
+/////  Must be provided by each supported wview station interface  //////
+
+// station-supplied init function
+// -- Can Be Asynchronous - event indication required --
+//
+// MUST:
+//   - set the 'stationGeneratesArchives' flag in WVIEWD_WORK:
+//     if the station generates archive records (TRUE) or they should be 
+//     generated automatically by the daemon from the sensor readings (FALSE)
+//   - Initialize the 'stationData' store for station work area
+//   - Initialize the interface medium
+//   - do initial LOOP acquisition
+//   - do any catch-up on archive records if there is a data logger
+//   - 'work->runningFlag' can be used for start up synchronization but should 
+//     not be modified by the station interface code
+//   - indicate init is done by sending the STATION_INIT_COMPLETE_EVENT event to
+//     this process (radProcessEventsSend (NULL, STATION_INIT_COMPLETE_EVENT, 0))
+//
+// OPTIONAL:
+//   - Initialize a state machine or any other construct required for the 
+//     station interface - these should be stored in the 'stationData' store
+//
+// 'archiveIndication' - indication callback used to pass back an archive record
+//   generated as a result of 'stationGetArchive' being called; should receive a
+//   NULL pointer for 'newRecord' if no record available; only used if 
+//   'stationGeneratesArchives' flag is set to TRUE by the station interface
+//
+// Returns: OK or ERROR
+//
+int stationInit
+(
+    WVIEWD_WORK     *work,
+    void            (*archiveIndication)(ARCHIVE_PKT  *newRecord)
+)
+{
+	pthread_t t;
+
+    memset(&bw9xxWorkData, 0, sizeof(bw9xxWorkData));
+
+    // save the archive indication callback (we should never need it)
+    ArchiveIndicator = archiveIndication;
+
+    // set our work data pointer
+    work->stationData = &bw9xxWorkData;
+
+	/* Create the rain accumulator (20 minute age) so we can
+	* compute rain rate.  Note that the WMR918 does this for a 10
+	* minute interval.  I have an idea the WMR918 bucket holds .25 to
+	* .5mm instead of the 1mm that the BW9xx does.  In order for us to
+	* get the reading low enough to read for a light rain (considered
+	* to be .10 inch per hour), we need to double this to 20 minutes.
+	* If left at 10 minutes, the small rate we could have would be
+	* .24 inches per hour, which is a bit more than a moderate rain.
+	* This 20 minute setting will get is down to .12 inch per hour.
+	* Of course, this is at the loss of a bit of resolution (such
+	* as a heavy downpour in a 10 minute window) so maybe there is
+	* a happy medium somewhere between 10 and 20.
+	*/
+    bw9xxWorkData.rainRateAccumulator = sensorAccumInit(20);
+
+    // The BW9xx doesn't generate archive files
+    work->stationGeneratesArchives = FALSE;
+
+    // initialize the medium abstraction based on user configuration
+    // we just set the fd to -1 so it is not used for select - 
+    // we won't really open a serial channel...
+    // FIXME: This may be key to getting rid of the pthread as the comment
+    // hints at setting it will get a select() ran.
+    work->medium.fd = -1;
+
+    // grab the station configuration now
+    if (stationGetConfigValueInt (work, STATION_PARM_ELEVATION, 
+		&bw9xxWorkData.elevation) == ERROR)
+    {
+        radMsgLog (PRI_HIGH,
+			"stationInit: stationGetConfigValueInt ELEV failed!");
+        (*(work->medium.exit)) (&work->medium);
+        return ERROR;
+    }
+
+    if (stationGetConfigValueFloat (work, STATION_PARM_LATITUDE, 
+		&bw9xxWorkData.latitude) == ERROR)
+    {
+        radMsgLog (PRI_HIGH,
+			"stationInit: stationGetConfigValueInt LAT failed!");
+        (*(work->medium.exit)) (&work->medium);
+        return ERROR;
+    }
+
+    if (stationGetConfigValueFloat (work, STATION_PARM_LONGITUDE, 
+		&bw9xxWorkData.longitude) == ERROR)
+    {
+        radMsgLog (PRI_HIGH,
+			"stationInit: stationGetConfigValueInt LONG failed!");
+        (*(work->medium.exit)) (&work->medium);
+        return ERROR;
+    }
+
+    if (stationGetConfigValueInt (work, STATION_PARM_ARC_INTERVAL, 
+		&bw9xxWorkData.archiveInterval) == ERROR)
+    {
+        radMsgLog (PRI_HIGH,
+			"stationInit: stationGetConfigValueInt ARCINT failed!");
+        (*(work->medium.exit)) (&work->medium);
+        return ERROR;
+    }
+
+    if (stationGetConfigValueInt (work, "HUMIDITY_IS_OUTSIDE", 
+		&weather_data.humidity_is_outside) == ERROR)
+    {
+		weather_data.humidity_is_outside = 0;
+    }
+
+	weather_data.device = work->stationDevice;
+	radMsgLog(PRI_STATUS, "Connecting to %s", weather_data.device);
+
+    // set the work archive interval now
+    work->archiveInterval = bw9xxWorkData.archiveInterval;
+
+    // sanity check the archive interval against the most recent record
+    if (stationVerifyArchiveInterval (work) == ERROR)
+    {
+        // bad magic!
+        radMsgLog (PRI_HIGH,
+			"stationInit: stationVerifyArchiveInterval failed!");
+        radMsgLog (PRI_HIGH,
+			"You must either move old /var/wview/archive files out "
+			"of the way -or-");
+        radMsgLog (PRI_HIGH, "fix the wview.conf setting...");
+        return ERROR;
+    }
+    else
+    {
+        radMsgLog (PRI_STATUS, "station archive interval: %d minutes",
+			work->archiveInterval);
+    }
+
+    // connect to station and begin reading data in a thread
+    // There's probably a way to do this without a thread
+    // as wview is made to have the ability to be asynchronous,
+    // but I haven't researched how, and implemented it yet.
+	pthread_mutex_init(&weather_data.locker, NULL);
+	weather_data.dataready = -1;
+	pthread_create(&t, NULL, readerThread, NULL);
+
+	// Loop until first round of data is ready from reader thread
+	// This could take up from one to two minutes
+	while (1)
+		{					
+		pthread_mutex_lock(&weather_data.locker);
+		if (weather_data.dataready == 1)
+			{
+			pthread_mutex_unlock(&weather_data.locker);
+			break;
+			}
+		pthread_mutex_unlock(&weather_data.locker);
+
+		sleep(1);
+		}
+
+	// never send rain data stored on station at startup,
+	// rain data should only be accumulated while wview runs
+	pthread_mutex_lock(&weather_data.locker);
+	weather_data.prevRain = weather_data.curRain;
+	pthread_mutex_unlock(&weather_data.locker);
+
+    // do the initial GetReadings now
+    // populate the LOOP structure
+    storeLoopPkt(&work->loopPkt);
+
+    // indicate successful completion
+    radProcessEventsSend (NULL, STATION_INIT_COMPLETE_EVENT, 0);
+
+    return OK;
+}
+
+// station-supplied exit function
+//
+// Returns: N/A
+//
+void stationExit (WVIEWD_WORK *work)
+{
+    return;
+}
+
+// station-supplied function to retrieve positional info (lat, long, elev) -
+// should populate 'work' fields: latitude, longitude, elevation
+// -- Synchronous --
+//
+// - If station does not store these parameters, they can be retrieved from the
+//   wview.conf file (see daemon.c for example conf file use) - user must choose
+//   station type "Generic" when running the wviewconfig script
+//
+// Returns: OK or ERROR
+//
+int stationGetPosition (WVIEWD_WORK *work)
+{
+    // just set the values from our internal store - we retrieved them in
+    // stationInit
+    work->elevation     = (short)bw9xxWorkData.elevation;
+    if (bw9xxWorkData.latitude >= 0)
+        work->latitude      = (short)((bw9xxWorkData.latitude*10)+0.5);
+    else
+        work->latitude      = (short)((bw9xxWorkData.latitude*10)-0.5);
+    if (bw9xxWorkData.longitude >= 0)
+        work->longitude     = (short)((bw9xxWorkData.longitude*10)+0.5);
+    else
+        work->longitude     = (short)((bw9xxWorkData.longitude*10)-0.5);
+    
+    radMsgLog (PRI_STATUS, "station location: elevation: %d feet",
+               work->elevation);
+
+    radMsgLog(PRI_STATUS,
+		"station location: latitude: %3.1f %c  longitude: %3.1f %c",
+		(float)abs(work->latitude)/10.0,
+		((work->latitude < 0) ? 'S' : 'N'),
+		(float)abs(work->longitude)/10.0,
+		((work->longitude < 0) ? 'W' : 'E'));
+
+    return OK;
+}
+
+// station-supplied function to indicate a time sync should be performed if the
+// station maintains time, otherwise may be safely ignored
+// -- Can Be Asynchronous --
+//
+// Returns: OK or ERROR
+//
+int stationSyncTime (WVIEWD_WORK *work)
+{
+    // Simulator does not keep time...
+    return OK;
+}
+
+// station-supplied function to indicate sensor readings should be performed -
+// should populate 'work' struct: loopPkt (see datadefs.h for minimum field reqs)
+// -- Can Be Asynchronous --
+//
+// - indicate readings are complete by sending the STATION_LOOP_COMPLETE_EVENT
+//   event to this process (radProcessEventsSend (NULL, STATION_LOOP_COMPLETE_EVENT, 0))
+//
+// Returns: OK or ERROR
+//
+int stationGetReadings(WVIEWD_WORK *work)
+{
+int ret;
+
+// populate the LOOP structure
+ret = storeLoopPkt(&work->loopPkt);
+
+if (ret)
+	{
+	// indicate we are done
+	radProcessEventsSend(NULL, STATION_LOOP_COMPLETE_EVENT, 0);
+	}
+    
+return OK;
+}
+
+// station-supplied function to indicate an archive record should be generated -
+// MUST populate an ARCHIVE_RECORD struct and indicate it to 'archiveIndication'
+// function passed into 'stationInit'
+// -- Asynchronous - callback indication required --
+//
+// Returns: OK or ERROR
+//
+// Note: 'archiveIndication' should receive a NULL pointer for the newRecord if
+//       no record is available
+// Note: This function will only be invoked by the wview daemon if the 
+//       'stationInit' function set the 'stationGeneratesArchives' to TRUE
+//
+int stationGetArchive (WVIEWD_WORK *work)
+{
+    // just indicate a NULL record, Simulator does not generate them (and this 
+    // function should never be called!)
+    (*ArchiveIndicator) (NULL);
+    return OK;
+}
+
+// station-supplied function to indicate data is available on the station 
+// interface medium (serial or ethernet) -
+// It is the responsibility of the station interface to read the data from the 
+// medium and process appropriately. The data does not have to be read within
+// the context of this function, but may be used to stimulate a state machine.
+// -- Synchronous --
+//
+// Returns: N/A
+//
+void stationDataIndicate (WVIEWD_WORK *work)
+{
+    // Simulator station is synchronous...
+    return;
+}
+
+// station-supplied function to indicate the interface timer has expired -
+// It is the responsibility of the station interface to start/stop the interface
+// timer as needed for the particular station requirements.
+// The station interface timer is specified by the 'ifTimer' member of the
+// WVIEWD_WORK structure. No other timers in that structure should be manipulated
+// in any way by the station interface code.
+// -- Synchronous --
+//
+// Returns: N/A
+//
+void stationIFTimerExpiry (WVIEWD_WORK *work)
+{
+    // Simulator station is synchronous...
+    return;
+}
+
+////////////****////  S T A T I O N   A P I   E N D  ////****////////////
+
+
+//  ... ----- static (local) methods ----- ...
+
+// reads from a file descriptor, a character at a time, placing
+// the data in a buffer until a newline is reached
+int ReadToNextLine(int fd, char *buf, int bufsize)
+{
+int ret;
+int count;
+
+count = 0;
+while (count < bufsize)
+	{
+	ret = read(fd, buf, sizeof (char));
+
+	/* stop on error */
+	if (ret == -1)
+		{
+		break;
+		}
+
+	/* stop on newline */
+	if (*buf == '\n')
+		{
+		break;
+		}
+
+	/* next */
+	buf++;
+	count++;
+	}
+
+return ret;
+}
+
+// if data is ready, convert the data from bw9xx specific readings
+// to wviewd readings
+static int storeLoopPkt (LOOP_PKT *dest)
+{
+time_t nowTime = time(NULL);
+
+pthread_mutex_lock(&weather_data.locker);
+
+if (weather_data.dataready < 1)
+	{
+	pthread_mutex_unlock(&weather_data.locker);
+
+	// return not ready to process
+	return 0;
+	}
+
+// these readings are straightforward
+dest->barometer = MillibarsToInches(weather_data.barometer);
+dest->outTemp = CelsiusToFahrenheit(weather_data.outTemp);
+dest->inTemp = CelsiusToFahrenheit(weather_data.inTemp);
+dest->windDir = weather_data.direction;
+
+// If outHumidity is set to 0, it causes a bug where updating the
+// sql database will fail (if sql is enabled), as it sets the
+// dewpoint to "nan".  I guess wview hasn't come across a station
+// that doesn't support outside humidity?  Set outHumidity to 1 to
+// prevent this.  The command that gave an error (at Dewpoint = nan)
+// is:
+// INSERT INTO archive SET RecordTime = "2008-09-10 10:10:00",ArcInt = 5,OutTemp = 76.300003,HiOutTemp = 76.300003,LowOutTemp = 76.300003,InTemp = 75.199997,Barometer = 30.002001,OutHumid = 0.000000,InHumid = 32.000000,Rain = 0.000000,HiRainRate = 0.000000,WindSpeed = 0.000000,HiWindSpeed = 2.000000,WindDir = 112,HiWindDir = 0,Dewpoint = nan,WindChill = 76.300003,HeatIndex = 74.153137
+dest->inHumidity = weather_data.inHumidity;
+if (weather_data.humidity_is_outside)
+	{
+	dest->outHumidity = weather_data.inHumidity;
+	}
+else
+	{
+	dest->outHumidity = 1;
+	}
+
+// these readings need to be rounded
+dest->windSpeed = (USHORT) (KmhToMph(weather_data.curWindSpeed) + 0.5);
+dest->windGust = (USHORT) (KmhToMph(weather_data.maxGust) + 0.5);
+
+// Rainfall must be calculated
+#if 0
+radMsgLog (PRI_STATUS, "curRain: %d, prevRain: %d",
+	weather_data.curRain, weather_data.prevRain);
+#endif
+
+// If current rainfall on station is reset, handle it */
+if (weather_data.prevRain > weather_data.curRain)
+	{
+#if 0
+	radMsgLog(PRI_STATUS, "Resetting prevRain which was %d to curRain"
+		"which is %d", weather_data.prevRain, weather_data.curRain);
+#endif
+	weather_data.prevRain = weather_data.curRain;
+	}
+
+dest->sampleRain = MmToInches(weather_data.curRain -
+	weather_data.prevRain);
+
+#if 0
+radMsgLog(PRI_STATUS, "Delivering %f rain", dest->sampleRain);
+#endif
+
+weather_data.prevRain = weather_data.curRain;
+
+// rain rate must be accumulated and calculated
+sensorAccumAddSample(bw9xxWorkData.rainRateAccumulator, nowTime,
+	dest->sampleRain);
+#if 0
+radMsgLog(PRI_STATUS, "Rain rate: %f",
+	sensorAccumGetTotal(bw9xxWorkData.rainRateAccumulator) * 3);
+#endif
+
+// retrieve rain rate from the accumulator
+dest->rainRate = sensorAccumGetTotal(bw9xxWorkData.rainRateAccumulator);
+dest->rainRate *= 3;      // Accumulator holds 20 minutes
+
+// calculate station pressure by giving a negative elevation 
+dest->stationPressure = wvutilsConvertSPToSLP(dest->barometer, 
+	dest->outTemp, (float)(-bw9xxWorkData.elevation));
+
+// calculate altimeter
+dest->altimeter = wvutilsConvertSPToAltimeter(dest->stationPressure,
+	(float)bw9xxWorkData.elevation);
+
+// calculate wind chill
+dest->windchill = wvutilsCalculateWindChill(dest->outTemp, 
+	(float)dest->windSpeed);
+
+// the following are not supported, but are required to be set
+dest->sampleET = 0;
+dest->radiation = 0;
+dest->UV = 0;
+dest->windGustDir= 0;
+
+/* The BW9xx series doesn't actually have an outside humidity
+ * sensor, making dew point and heat index calculations invalid.
+ */
+dest->dewpoint = 0;
+dest->heatindex = 0;
+
+/* Decrement dataready since it has been used */
+weather_data.dataready = 0;;
+pthread_mutex_unlock(&weather_data.locker);
+
+// return that data was processed
+return 1;
+}
+
+// Parse and return data value coming from ws9xxd
+static char *getData(char *monitorstring, char *datastring)
+{
+char *s;
+char *space;
+
+// advance to end of description text
+s = datastring + strlen(monitorstring);
+
+// NULL if getting back a dash
+// FIXME: Make sure callers can handle this.  Perhaps bring wview offline?
+if (*s == '-')
+	{
+	return NULL;
+	}
+
+
+// advance to the space between the data and the units and null out if found
+space = (strchr(s, ' '));
+if (space != NULL)
+	{
+	*space = '\0';
+	}
+
+return s;
+}
+
+// Convert mm (int) to inches (float)
+static float MmToInches(int mm)
+{
+float ret;
+ret = (float) mm * (float) .04;
+return ret;
+}
+
+// Convert Celsius to Fahrenheight
+static float CelsiusToFahrenheit(float c)
+{
+float ret;
+
+ret = (float) 9.0 / (float) 5.0;
+ret = ret * c;
+ret = ret + 32.0;
+
+return ret;
+}
+
+// Convert millibars to inches
+static float MillibarsToInches(float mb)
+{
+return mb * .02953;
+}
+
+// Convert kilometers per hour to miles per hour
+static float KmhToMph(float kmh)
+{
+float ret;
+
+ret = (float) kmh / (float) 1.61;
+
+return ret;
+}
+
+static void processor_cb(char *buf, struct ws9xxd_dataline *d)
+{
+char *s;
+char *datatext = "DATA: ";
+
+if (d->prelog)
+	{
+	(*(d->prelog))(buf, d);
+	}
+
+if (memcmp(datatext, buf, strlen(datatext)) == 0)
+	{
+	s = getData(d->desc, buf);
+	}
+else
+	{
+	/* assume csv */
+	s = strstr(buf, d->desc_csv);
+	if (s != NULL)
+		{
+		s = s + strlen(d->desc_csv);
+		}
+	}
+
+if (s != NULL)
+	{
+	if (d->stringtoval != NULL)
+		{
+		pthread_mutex_lock(&weather_data.locker);
+		(*(d->stringtoval))(s, d->value);
+		pthread_mutex_unlock(&weather_data.locker);
+		}
+	}
+
+if (d->postlog)
+	{
+	(*(d->postlog))(buf, d);
+	}
+
+}
+
+static void prelog_cb(char *buf, struct ws9xxd_dataline *d)
+{
+radMsgLog(PRI_STATUS, buf);
+}
+
+static void postlog_int_cb(char *buf, struct ws9xxd_dataline *d)
+{
+radMsgLog(PRI_STATUS, "Value is: %d", *((int *) d->value));
+}
+
+static void postlog_float_cb(char *buf, struct ws9xxd_dataline *d)
+{
+radMsgLog(PRI_STATUS, "Value is: %f", *((float *) d->value));
+}
+
+static void atof_cb(const char *s, void *value)
+{
+*((float *) value) = atof(s);
+}
+
+static void atoi_cb(const char *s, void *value)
+{
+*((int *) value) = atoi(s);
+}
+
+static void increment_cb(const char *s, void *value)
+{
+*((int *) value) = *((int *) value) + 1;
+}
+
+// Used as a thread to monitor incoming data from ws9xxd and load it
+// as it is received, to the global "struct bw9xx_data weather_data" 
+static void *readerThread(void *notused)
+{
+char *path = weather_data.device;
+char buf[100];
+struct sockaddr_un sun;
+struct ws9xxd_dataline *wd;
+int fd;
+int ret;
+
+notused = notused;
+
+/* Loop until connect with socket is successful */
+while (1)
+	{
+	fd = socket(PF_UNIX, SOCK_STREAM, 0);
+	if (fd == -1)
+		{
+		return NULL;
+		}
+
+	memset(&sun, 0, sizeof (sun));
+	sun.sun_family = AF_UNIX;
+	memcpy(sun.sun_path, path, strlen(path) + 1);
+
+	while (1)
+		{
+		ret = connect(fd, (struct sockaddr *) &sun, sizeof (sun));
+		if (ret == -1)
+			{
+			sleep(1);
+			continue;
+			}
+		else
+			{
+			radMsgLog(PRI_STATUS, "Connected at %s", weather_data.device);
+			break;
+			}
+		}
+
+	memset(buf, 0, sizeof(buf));
+	ret = ReadToNextLine(fd, buf, sizeof(buf));
+	while (ret > 0)
+		{
+		// init to beginning of data to monitor array
+		wd = datums;
+		while (wd->desc != NULL)
+			{
+			// if data from ws9xxd and monitor description match
+			// then process
+			if (strstr(buf, wd->desc))
+				{
+				// process ws9xxd data
+				(*(wd->processor))(buf, wd);
+				}
+			else if (strstr(buf, wd->desc_csv))
+				{
+				/* data must be in csv */
+				(*(wd->processor))(buf, wd);
+				}
+				
+			wd++;
+			}
+
+		memset(buf, 0, sizeof(buf));
+		ret = ReadToNextLine(fd, buf, sizeof(buf));
+		}
+
+	close(fd);
+
+	radMsgLog(PRI_STATUS, "Lost connection with %s", weather_data.device);
+
+	/* Reset dataready back to -1 to wait for another full
+	 * round of data once we are connected to ws9xxd again
+	 */
+	pthread_mutex_lock(&weather_data.locker);
+	weather_data.dataready = -1;;
+	pthread_mutex_unlock(&weather_data.locker);
+	}
+
+return NULL;
+}
--- wview-5.5.0/./configure.in	2009-05-14 06:58:48.000000000 -0500
+++ wview-5.5.0-mods/./configure.in	2009-05-14 12:06:07.000000000 -0500
@@ -53,6 +53,14 @@
 esac],[station_sim=false])
 AM_CONDITIONAL(STATION_SIM, test x$station_sim = xtrue)
 
+AC_ARG_ENABLE(station-bw9xx,
+[  --enable-station-bw9xx           build for the BW9xx Station],
+[case "${enableval}" in
+  yes) station_bw9xx=true ;;
+  no)  station_bw9xx=false ;;
+  *) station_bw9xx=false ;;
+esac],[station_bw9xx=false])
+AM_CONDITIONAL(STATION_BW9XX, test x$station_bw9xx = xtrue)
 
 # Check for big endian host:
 AC_C_BIGENDIAN([HOST_IS_BIGENDIAN="1"], [HOST_IS_BIGENDIAN="0"], [HOST_IS_BIGENDIAN="0"])
@@ -109,6 +117,7 @@
 
 AC_CONFIG_FILES([Makefile \
                  stations/Makefile \
+                 stations/BW9xx/Makefile \
                  stations/Simulator/Makefile \
                  stations/VantagePro/Makefile \
                  stations/VantagePro/vpconfig/Makefile \
--- wview-5.5.0/./wviewconfig/Makefile.am	2009-02-04 23:09:28.000000000 -0600
+++ wview-5.5.0-mods/./wviewconfig/Makefile.am	2009-05-14 11:59:58.000000000 -0500
@@ -19,6 +19,9 @@
 if STATION_WMR918
 MY_STATION_TYPE = WMR918
 else
+if STATION_BW9XX
+MY_STATION_TYPE = BW9XX
+else
 if STATION_SIM
 MY_STATION_TYPE = Simulator
 else
@@ -28,6 +31,7 @@
 endif
 endif
 endif
+endif
 
 wviewconfig: $(srcdir)/wviewconfig.sh
 	rm -f wviewconfig
--- wview-5.5.0/./examples/conf/wview-conf.sql	2009-05-02 12:35:26.000000000 -0500
+++ wview-5.5.0-mods/./examples/conf/wview-conf.sql	2009-05-14 18:02:45.000000000 -0500
@@ -7,9 +7,9 @@
 INSERT INTO "config" VALUES('ENABLE_FTP','no','Run FTP daemon to transfer web site/generated files to a remote server?',NULL);
 INSERT INTO "config" VALUES('ENABLE_SSH','no','Run SSH daemon to transfer web site/generated files to a remote server?',NULL);
 INSERT INTO "config" VALUES('ENABLE_PROCMON','yes','Run process monitor daemon to restart failed/hung daemons?',NULL);
-INSERT INTO "config" VALUES('STATION_TYPE','Simulator','Station type - one of Simulator, VantagePro, WXT510, WS-2300, WMR918:',NULL);
+INSERT INTO "config" VALUES('STATION_TYPE','BW9xx','Station type - one of Simulator, VantagePro, WXT510, WS-2300, WMR918, BW9xx:',NULL);
 INSERT INTO "config" VALUES('STATION_INTERFACE','serial','Physical interface to the weather station - one of serial or ethernet (usb is considered serial):',NULL);
-INSERT INTO "config" VALUES('STATION_DEV','/dev/ttyUSB0','Weather station serial device (/dev/ttyS0, /dev/ttyUSB0, etc.):',NULL);
+INSERT INTO "config" VALUES('STATION_DEV','/usr/local/etc/ws9xxd/wsd','Weather station serial device (/dev/ttyS0, /dev/ttyUSB0, etc.):',NULL);
 INSERT INTO "config" VALUES('STATION_HOST','10.10.10.10','Hostname or IP address (ethernet only):',NULL);
 INSERT INTO "config" VALUES('STATION_PORT','2102','Host TCP port to the weather station (ethernet only):',NULL);
 INSERT INTO "config" VALUES('STATION_RAIN_SEASON_START','1','Station rain season start month (1 - 12):',NULL);
@@ -22,7 +22,7 @@
 INSERT INTO "config" VALUES('STATION_LATITUDE','33.6','Weather station latitude (decimal degrees, NORTH is positive - SOUTH is negative):',NULL);
 INSERT INTO "config" VALUES('STATION_LONGITUDE','-96.9','Weather station longitude (decimal degrees, EAST is positive - WEST is negative):',NULL);
 INSERT INTO "config" VALUES('STATION_ARCHIVE_INTERVAL','5','Weather data archive interval (minutes, one of 5, 10, 15, 30):',NULL);
-INSERT INTO "config" VALUES('STATION_POLL_INTERVAL','30','Weather station sensor poll interval (seconds) - should be divisor of 60:',NULL);
+INSERT INTO "config" VALUES('STATION_POLL_INTERVAL','15','Weather station sensor poll interval (seconds) - should be divisor of 60:',NULL);
 INSERT INTO "config" VALUES('STATION_PUSH_INTERVAL','60','Current conditions data push interval (seconds) - for wvalarmd and possibly others:',NULL);
 INSERT INTO "config" VALUES('STATION_VERBOSE_MSGS','00000011','Daemon Verbose Log Mask: 00000001 - wviewd,00000010 - htmlgend,00000100 - wvalarmd,00001000 - wviewftpd,00010000 - wviewsshd,00100000 - wvcwopd,01000000 - wvhttpd:',NULL);
 INSERT INTO "config" VALUES('STATION_DO_RCHECK','no','Generate RX check data (populate rxCheck.png chart, VP only)?',NULL);
--- wview-5.5.0/./Makefile.am	2009-05-14 06:57:21.000000000 -0500
+++ wview-5.5.0-mods/./Makefile.am	2009-05-14 18:07:39.000000000 -0500
@@ -39,12 +39,16 @@
 if STATION_SIM
     STATION_T = wviewd_sim
 else
+if STATION_BW9XX
+    STATION_T = wviewd_bw9xx
+else
     STATION_T = wviewd_vpro
 endif
 endif
 endif
 endif
 endif
+endif
 
 WV_CONFIG_DIR 		= $(prefix)/etc/wview
 WV_RUN_DIR    		= $(prefix)/var/wview
