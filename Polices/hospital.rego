# =================================================== #
# Project: Hospital
# =================================================== #
package hospital.auth

default allow = false

# INFO : Health Check
allow {
	input.path = "/healthz"
}

# =================================================== #
# General Rules
# =================================================== #
is_day_hour {
	[hour, _, _] := time.clock(time.now_ns())
	hour >= 0
	hour < 12
}

is_week_day {
	weekday := time.weekday(time.now_ns())
	weekday != "Friday"
}

# INFO: working Hours = work day && day hours
is_work_hours {
	is_day_hour
	is_week_day
}

# =================================================== #
# Rule: Doctor
# =================================================== #
allow {
	input.user.role == "doctor"
	startswith(input.path, "/hospital/doctor")
}

allow {
	input.user.role == "doctor"
	input.method = {"GET", "POST"}[_]
	input.path = "/hospital/recipes"
}

# =================================================== #
# Rule: Clerk
# =================================================== #
allow {
	input.user.role == "clerk"
	startswith(input.path, "/hospital/clerk")
	#is_work_hours
}

allow {
	input.user.role = "clerk"
	input.method = "PUT"
	input.path = "/hospital/recipes"
	#is_work_hours
}
