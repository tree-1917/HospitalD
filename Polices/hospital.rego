# =================================================== #
# Project: Hospital
# =================================================== #
package hospital.auth

default allow = false

# INFO: Health Rule
allow {
	input.path == "/healthz"
}

# =================================================== #
# Rule: Global
# =================================================== #

is_hours_day {
	[hours, _, _] := time.clock(time.now_ns())
	hours >= 9 # 9 AM

	# TEST: For Test will Make this 15 which must be 17
	hours < 15 # 5 PM
}

is_work_day {
	today := time.weekday(time.now_ns())
	today != "Friday"
}

# INFO: work_hours = work_day + hour_day
is_work_hours {
	is_work_day
	is_hours_day
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
	input.method == {"GET", "POST"}[_]
	input.path == "/hospital/recipes"
}

# =================================================== #
# Rule: Clerk
# =================================================== #
allow {
	input.user.role == "clerk"
	startswith(input.path, "/hospital/clerk")
	is_work_hours
}

allow {
	input.user.role == "clerk"
	input.method == "PUT"
	input.path == "/hospital/recipes"
	is_work_hours
}
