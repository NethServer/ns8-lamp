*** Settings ***
Library    SSHLibrary
Resource    api.resource

*** Keywords ***
Retry test
    [Arguments]    ${keyword}
    Wait Until Keyword Succeeds    60 seconds    1 second    ${keyword}

Backend URL is reachable
    ${rc} =    Execute Command    curl -f ${backend_url}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check PHP version
    [Arguments]    ${php_version}
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"create_mysql_user": true,"host": "lamp.fqdn.test","http2https": true,"lets_encrypt": false,"mysql_admin_pass": "Nethesis,1234","mysql_user_db": "database","mysql_user_name": "admin","mysql_user_pass": "Nethesis,1234","php_max_execution_time": "3600","php_memory_limit": "2000","php_upload_max_filesize": "2000","php_version": "${php_version}","phpmyadmin_enabled": true}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    Retry test    Backend URL is reachable
    ${output} =    Execute Command    curl -f ${backend_url}/phpinfo.php
    Should Contain    ${output}    PHP ${php_version}
    Should Contain    ${output}    <tr><td class="e">memory_limit</td><td class="v">2000M</td><td class="v">2000M</td></tr>
    Should Contain    ${output}    <tr><td class="e">upload_max_filesize</td><td class="v">2000M</td><td class="v">2000M</td></tr>
    Should Contain    ${output}    <tr><td class="e">post_max_size</td><td class="v">2000M</td><td class="v">2000M</td></tr>
    Should Contain    ${output}    <tr><td class="e">max_execution_time</td><td class="v">3600</td><td class="v">3600</td></tr>

Check phpMyAdmin is accessible
    # Verify phpMyAdmin page loads
    ${response} =    Execute Command    curl -s -k "${backend_url}/phpmyadmin/"
    Should Contain    ${response}    phpMyAdmin
    Should Contain    ${response}    name="pma_username"
    Should Contain    ${response}    name="pma_password"

*** Test Cases ***
Check if lamp is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if lamp can be configured
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"create_mysql_user": true,"host": "lamp.fqdn.test","http2https": true,"lets_encrypt": false,"mysql_admin_pass": "Nethesis,1234","mysql_user_db": "database","mysql_user_name": "admin","mysql_user_pass": "Nethesis,1234","php_max_execution_time": "3600","php_memory_limit": "2000","php_upload_max_filesize": "2000","php_version": "7.4","phpmyadmin_enabled": true}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Retrieve lamp backend URL
    # Assuming the test is running on a single node cluster
    ${response} =    Run task     module/traefik1/get-route    {"instance":"${module_id}"}
    Set Suite Variable    ${backend_url}    ${response}[url]

Check if lamp works as expected
    Retry test    Backend URL is reachable

Test to reach phpMyAdmin login page
    Check phpMyAdmin is accessible

Check PHP 7.4
    Check PHP version    7.4

Check PHP 8.0
    Check PHP version    8.0

Check PHP 8.1
    Check PHP version    8.1

Check PHP 8.2
    Check PHP version    8.2

Check PHP 8.3
    Check PHP version    8.3

Check PHP 8.4
    Check PHP version    8.4

Check PHP 8.5
    Check PHP version    8.5

Check if lamp is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0