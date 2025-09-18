# 7DTD-AutoRestart-and-Display
7 Days to Die Server Auto-Restart Script with Live Error/Warning Monitoring.

Overview
This advanced batch script provides automated server management for 7 Days to Die dedicated servers with real-time error and warning monitoring, persistent logging, and automatic restart capabilities.


Features:

Auto-Restart System

Automatically restarts the server when it stops/crashes
Tracks restart sessions with sequential numbering
Maintains running totals across all sessions
8-second countdown before restart (cancelable with Ctrl+C)

Live Error/Warning Monitoring

Real-time detection of errors (ERR) and exceptions (EXC) as they occur
Live warning monitoring (WRN) with instant display
Separate PowerShell window for monitoring while server runs normally
Color-coded display: Red errors, Dark Red exceptions, Yellow warnings
Filtering to exclude shader/graphics compatibility spam

Persistent Logging System

server_errors.log - All errors and exceptions with timestamps
server_warnings.log - All warnings with timestamps
server_summary.log - Session summaries with counts and timing
Automatic log rotation - keeps only latest 20 server log files

Intelligent Filtering

Ignores shader errors
Ignores graphics warnings
Focuses on real issues like XML parsing errors, network problems, mod conflicts

Server Management

Config file validation (checks for serverconfig.xml)
Timestamped log files for each session
Exit code tracking for debugging

HOW TO:

Place the batch file in your 7DTD server directory
Run the batch file
Monitor PowerShell for server status and issues
Use CSMM, other server management), or Ctrl+C to stop/restart server

Compatibility:

Windows Server
7 Days to Die Dedicated Server (any version)
Compatible with CSMM and other server management tools
Works with modded servers and custom configurations

Benefits:

Reduces downtime through automatic restarts
Provides visibility into server health and issues
Maintains detailed logs for troubleshooting
Filters noise to focus on actionable problems
Integrates seamlessly with existing server management workflows
