## get commit sha from remote git repository 

Query remote git repo and display last commit sha.

usage: app -r ... -b ... [--service ...] [--help]

### Required parameters:

-r		required repo name

-b		required branch name

### Optional parameters:

--service	service name, for now only "github" is supported

--help		display this help

### Usage example:
 
./app -r laravel-shift/laravel-5.3 -b master

./app -r atlassian/bitbucketjs -b master --service=bitbucked

./app --help
