ROOT_DIR = ..
include ${ROOT_DIR}/_scripts/Makefile.projects
include ${ROOT_DIR}/_scripts/Makefile.instance

.PHONY: config-hook
config-hook:
	@${BIN}/reconfigure_ask ${ENV_FILE} YOURLS_TRAEFIK_HOST "Enter the YOURLS domain name" yourls${INSTANCE_URL_SUFFIX}.${ROOT_DOMAIN}
	@${BIN}/reconfigure ${ENV_FILE} YOURLS_INSTANCE=$${instance:-default}
	@${BIN}/reconfigure_auth ${ENV_FILE} YOURLS
	@echo
	@${BIN}/reconfigure_ask ${ENV_FILE} YOURLS_USER "Enter the admin username for your YOURLS instance"
	@${BIN}/reconfigure_ask ${ENV_FILE} YOURLS_PASS "Enter the password for '"$$(${BIN}/dotenv -f ${ENV_FILE} get YOURLS_USER)"'"
	@echo
	@${BIN}/reconfigure_password ${ENV_FILE} MYSQL_ROOT_PASSWORD 45
	@${BIN}/reconfigure_password ${ENV_FILE} YOURLS_COOKIEKEY 45
	@echo

.PHONY: override-hook
override-hook:
#### This sets the override template variables for docker-compose.instance.yaml:
#### The template dynamically renders to docker-compose.override_{DOCKER_CONTEXT}_{INSTANCE}.yaml
#### These settings are used to automatically generate the service container labels, and traefik config, inside the template.
#### The variable arguments have three forms: `=` `=:` `=@`
####   name=VARIABLE_NAME    # sets the template 'name' field to the value of VARIABLE_NAME found in the .env file
####                         # (this hardcodes the value into docker-compose.override.yaml)
####   name=:VARIABLE_NAME   # sets the template 'name' field to the literal string 'VARIABLE_NAME'
####                         # (this hardcodes the string into docker-compose.override.yaml)
####   name=@VARIABLE_NAME   # sets the template 'name' field to the literal string '${VARIABLE_NAME}'
####                         # (used for regular docker-compose expansion of env vars by name.)
	@${BIN}/docker_compose_override ${ENV_FILE} project=:yourls instance=@YOURLS_INSTANCE traefik_host=@YOURLS_TRAEFIK_HOST http_auth=YOURLS_HTTP_AUTH http_auth_var=@YOURLS_HTTP_AUTH ip_sourcerange=@YOURLS_IP_SOURCERANGE oauth2=YOURLS_OAUTH2 authorized_group=YOURLS_OAUTH2_AUTHORIZED_GROUP enable_mtls_auth=YOURLS_MTLS_AUTH mtls_authorized_certs=YOURLS_MTLS_AUTHORIZED_CERTS

.PHONY: shell
shell:
	@container=$$(eval "${BIN}/script-wizard choose 'docker exec -it into which container?' 'yourls' 'mysql' --default 'yourls'") && make --no-print-directory docker-compose-shell SERVICE=$${container}

open-hook:
	${BIN}/open /admin
	
.PHONY: list-admin-users # List admin users
list-admin-users:
# Pull the config.php file from the Docker container
	@docker cp -a yourls-yourls-1:/var/www/html/user/config.php config.php.temp > /dev/null 2>&1
	@echo "Existing admin users:"
# Extract the usernames from $yourls_user_passwords array
	@grep -oP "'\K[^']+(?=' *=>)" config.php.temp
# Clean up temporary file
	@rm config.php.temp
	@echo

.PHONY: add-admin-users # Add admin users
add-admin-users:
# Pull the config.php file from the Docker container
	@docker cp -a yourls-yourls-1:/var/www/html/user/config.php config.php.temp > /dev/null 2>&1
	@bash -c '\
		while true; do \
# Ask for username(s) and password(s) to add \
			read -p "Enter username (leave blank to finish): " username; \
			if [ -z "$$username" ]; then break; fi; \
			read -p "Enter password: " password; \
# Insert the new user into the $yourls_user_passwords array \
			sed -i "/\$yourls_user_passwords\s*=/a \ \ '\''$$username'\'' => '\''$$password'\''," config.php.temp; \
		done'
# Copy the modified config.php back into the container
	@docker cp -a config.php.temp yourls-yourls-1:/var/www/html/user/config.php > /dev/null 2>&1
# Clean up temporary file
	@rm config.php.temp
	@echo
	@echo 'Added the new admin users!'
	@echo

.PHONY: delete-admin-users # Delete admin users
delete-admin-users:
# Pull the config.php file from the Docker container
	@docker cp -a yourls-yourls-1:/var/www/html/user/config.php config.php.temp > /dev/null 2>&1
	@echo "Existing admin users:"
# Extract the usernames from $yourls_user_passwords array
	@grep -oP "'\K[^']+(?=' *=>)" config.php.temp
	@while true; do \
# Ask which user(s) to delete \
		read -p "Enter the admin user(s) to delete (space-separated): " users; \
		if [ -z "$$users" ]; then break; fi; \
		for user in $$users; do \
# Only delete username if it already exists \
			if ! grep -P "'$$user' *=>" config.php.temp > /dev/null 2>&1; then \
				echo "$$user is not an existing admin user."; \
				users=$$(echo "$$users" | sed "s/\b$$user\b//g" | xargs); \
				continue; \
			fi; \
# Delete the user(s) from the $yourls_user_passwords array \
			sed -i "/'$$user' *=>/d" config.php.temp; \
		done; \
		echo "Deleted the admin users: $$users"; \
		break; \
	done
# Copy the modified config.php back into the container
	@docker cp -a config.php.temp yourls-yourls-1:/var/www/html/user/config.php > /dev/null 2>&1
# Clean up temporary file
	@rm config.php.temp
	@echo
