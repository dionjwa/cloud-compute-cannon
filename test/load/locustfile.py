import json
from locust import HttpLocust, TaskSet

headers = {'bnr_probe_id': '0af277c0-5aed-429c-b667-1e01c44f9477', 'content-type': 'application/json'}

with open('/test/turbojob-glimmer.json') as data_file:
    glimmerJson = json.load(data_file)

with open('/test/turbojob-gsl.json') as data_file:
    gslJson = json.load(data_file)

def login(l):
		l.client.post("/login", {"username":"ellen_key", "password":"education"})

def computejob(l):
	l.client.get("/")

def turbojob(l):
	l.client.get("/profile")

def glimmerjob(l):
	l.client.post("/v1/runturbojson", data=json.dumps(glimmerJson), headers=headers)

def gsljob(l):
	l.client.post("/v1/runturbojsonv2", gslJson, headers=headers)

class CCCLoadTasks(TaskSet):
	tasks = {glimmerjob:1}

class WebsiteUser(HttpLocust):
	task_set = CCCLoadTasks
	min_wait = 100
	max_wait = 9000



