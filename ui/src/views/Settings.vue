<!--
  Copyright (C) 2022 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <cv-text-input
              :label="$t('settings.lamp_fqdn')"
              placeholder="lamp.example.org"
              v-model.trim="host"
              class="mg-bottom"
              :invalid-message="$t(error.host)"
              :disabled="stillLoading"
              ref="host"
            >
            </cv-text-input>
            <NsToggle
              value="letsEncrypt"
              :label="core.$t('apps_lets_encrypt.request_https_certificate')"
              v-model="isLetsEncryptEnabled"
              :disabled="stillLoading"
              class="mg-bottom"
            >
              <template #tooltip>
                <div class="mg-bottom-sm">
                  {{ core.$t("apps_lets_encrypt.lets_encrypt_tips") }}
                </div>
                <div class="mg-bottom-sm">
                  <cv-link @click="goToCertificates">
                    {{ core.$t("apps_lets_encrypt.go_to_tls_certificates") }}
                  </cv-link>
                </div>
              </template>
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </NsToggle>
            <cv-row
              v-if="isLetsEncryptCurrentlyEnabled && !isLetsEncryptEnabled"
            >
              <cv-column>
                <NsInlineNotification
                  kind="warning"
                  :title="
                    core.$t('apps_lets_encrypt.lets_encrypt_disabled_warning')
                  "
                  :description="
                    core.$t(
                      'apps_lets_encrypt.lets_encrypt_disabled_warning_description',
                      {
                        node: this.status.node_ui_name
                          ? this.status.node_ui_name
                          : this.status.node,
                      }
                    )
                  "
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <cv-toggle
              value="httpToHttps"
              :label="$t('settings.http_to_https')"
              v-model="isHttpToHttpsEnabled"
              :disabled="stillLoading"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </cv-toggle>
            <NsTextInput
              :label="$t('settings.mysql_admin_pass')"
              v-model="mysql_admin_pass"
              type="password"
              :placeholder="$t('settings.mysql_admin_pass_placeholder')"
              :disabled="
                loading.getConfiguration ||
                loading.configureModule ||
                !firstConfig
              "
              :invalid-message="$t(error.mysql_admin_pass)"
              ref="mysql_admin_pass"
              :helper-text="$t('settings.mysql_admin_pass_helper')"
            >
              <template #tooltip>{{
                $t("settings.mysql_admin_pass_tooltip")
              }}</template>
            </NsTextInput>
            <!-- advanced options -->
            <cv-accordion ref="accordion" class="maxwidth mg-bottom">
              <cv-accordion-item :open="toggleAccordion[0]">
                <template slot="title">{{ $t("settings.advanced") }}</template>
                <template slot="content">
                  <cv-toggle
                    value="phpmyadmin_enabled"
                    :label="$t('settings.phpmyadmin_enabled')"
                    v-model="phpmyadmin_enabled"
                    :disabled="stillLoading"
                    class="mg-bottom"
                  >
                    <template slot="text-left">{{
                      $t("settings.disabled")
                    }}</template>
                    <template slot="text-right">{{
                      $t("settings.enabled")
                    }}</template>
                  </cv-toggle>
                  <cv-toggle
                    value="create_mysql_user"
                    :label="$t('settings.create_mysql_user')"
                    v-model="create_mysql_user"
                    :disabled="
                      loading.getConfiguration ||
                      loading.configureModule ||
                      !firstConfig
                    "
                    class="mg-bottom"
                  >
                    <template slot="text-left">{{
                      $t("settings.disabled")
                    }}</template>
                    <template slot="text-right">{{
                      $t("settings.enabled")
                    }}</template>
                  </cv-toggle>
                  <template v-if="create_mysql_user">
                    <NsTextInput
                      :label="$t('settings.mysql_user_name')"
                      v-model="mysql_user_name"
                      :placeholder="$t('settings.mysql_user_name_placeholder')"
                      :disabled="
                        loading.getConfiguration ||
                        loading.configureModule ||
                        !firstConfig
                      "
                      :invalid-message="$t(error.mysql_user_name)"
                      ref="mysql_user_name"
                      :helper-text="$t('settings.mysql_user_name_helper')"
                    >
                      <template #tooltip>{{
                        $t("settings.mysql_user_name_tooltip")
                      }}</template>
                    </NsTextInput>
                    <NsTextInput
                      :label="$t('settings.mysql_user_pass')"
                      v-model="mysql_user_pass"
                      :placeholder="$t('settings.mysql_user_pass_placeholder')"
                      type="password"
                      :disabled="
                        loading.getConfiguration ||
                        loading.configureModule ||
                        !firstConfig
                      "
                      :invalid-message="$t(error.mysql_user_pass)"
                      ref="mysql_user_pass"
                      :helper-text="$t('settings.mysql_user_pass_helper')"
                    >
                      <template #tooltip>{{
                        $t("settings.mysql_user_pass_tooltip")
                      }}</template>
                    </NsTextInput>
                    <NsTextInput
                      :label="$t('settings.mysql_user_db')"
                      v-model="mysql_user_db"
                      :placeholder="$t('settings.mysql_user_db_placeholder')"
                      :disabled="
                        loading.getConfiguration ||
                        loading.configureModule ||
                        !firstConfig
                      "
                      :invalid-message="$t(error.mysql_user_db)"
                      ref="mysql_user_db"
                      :helper-text="$t('settings.mysql_user_db_helper')"
                    >
                      <template #tooltip>{{
                        $t("settings.mysql_user_db_tooltip")
                      }}</template>
                    </NsTextInput>
                  </template>
                  <cv-dropdown
                    :light="true"
                    :value="PhpVersion"
                    v-model="PhpVersion"
                    :up="false"
                    :inline="false"
                    :helper-text="
                      $t('settings.container_version_will_be_installed')
                    "
                    :hide-selected="false"
                    :invalid-message="$t(error.PhpVersion)"
                    :label="$t('settings.select_php_version')"
                    :disabled="stillLoading"
                  >
                    <cv-dropdown-item value="7.4">PHP 7.4</cv-dropdown-item>
                    <cv-dropdown-item value="8.0">PHP 8.0</cv-dropdown-item>
                    <cv-dropdown-item value="8.1">PHP 8.1</cv-dropdown-item>
                    <cv-dropdown-item value="8.2">PHP 8.2</cv-dropdown-item>
                    <cv-dropdown-item value="8.3">PHP 8.3</cv-dropdown-item>
                    <cv-dropdown-item value="8.4">PHP 8.4</cv-dropdown-item>
                  </cv-dropdown>
                  <NsTextInput
                    :label="$t('settings.php_upload_max_filesize')"
                    v-model="php_upload_max_filesize"
                    type="number"
                    :min="100"
                    :max="2048"
                    :placeholder="
                      $t('settings.php_upload_max_filesize_placeholder')
                    "
                    :disabled="stillLoading"
                    :invalid-message="$t(error.php_upload_max_filesize)"
                    ref="php_upload_max_filesize"
                    :helper-text="$t('settings.php_upload_max_filesize_helper')"
                  >
                    <template #tooltip>{{
                      $t("settings.php_upload_max_filesize_tooltip")
                    }}</template>
                  </NsTextInput>
                  <NsTextInput
                    :label="$t('settings.php_memory_limit')"
                    v-model="php_memory_limit"
                    type="number"
                    :min="512"
                    :max="4096"
                    :placeholder="$t('settings.php_memory_limit_placeholder')"
                    :disabled="stillLoading"
                    :invalid-message="$t(error.php_memory_limit)"
                    ref="php_memory_limit"
                    :helper-text="$t('settings.php_memory_limit_helper')"
                  >
                    <template #tooltip>{{
                      $t("settings.php_memory_limit_tooltip")
                    }}</template>
                  </NsTextInput>
                </template>
              </cv-accordion-item>
            </cv-accordion>
            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <cv-row v-if="validationErrorDetails.length">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="
                    core.$t('apps_lets_encrypt.cannot_obtain_certificate')
                  "
                  :showCloseButton="false"
                >
                  <template #description>
                    <div class="flex flex-col gap-2">
                      <div
                        v-for="(detail, index) in validationErrorDetails"
                        :key="index"
                      >
                        {{ detail }}
                      </div>
                    </div>
                  </template>
                </NsInlineNotification>
              </cv-column>
            </cv-row>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="stillLoading"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      status: {},
      validationErrorDetails: [],
      urlCheckInterval: null,
      host: "",
      isLetsEncryptEnabled: false,
      isLetsEncryptCurrentlyEnabled: false,
      isHttpToHttpsEnabled: true,
      phpmyadmin_enabled: true,
      create_mysql_user: false,
      php_upload_max_filesize: "100",
      php_memory_limit: "512",
      mysql_user_name: "",
      mysql_user_db: "",
      mysql_user_pass: "",
      mysql_admin_pass: "",
      firstConfig: true,
      PhpVersion: "8.3",
      loading: {
        getConfiguration: false,
        configureModule: false,
        getStatus: false,
      },
      error: {
        phpVersion: "",
        getConfiguration: "",
        configureModule: "",
        host: "",
        lets_encrypt: "",
        http2https: "",
        mysql_user_name: "",
        mysql_user_db: "",
        mysql_user_pass: "",
        mysql_admin_pass: "",
        php_upload_max_filesize: "",
        php_memory_limit: "",
        getStatus: false,
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    stillLoading() {
      return (
        this.loading.getConfiguration ||
        this.loading.configureModule ||
        this.loading.getStatus
      );
    },
  },
  created() {
    this.getConfiguration();
    this.getStatus();
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  methods: {
    goToCertificates() {
      this.core.$router.push("/settings/tls-certificates");
    },
    async getStatus() {
      this.loading.getStatus = true;
      this.error.getStatus = "";
      const taskAction = "get-status";
      const eventId = this.getUuid();
      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getStatusAborted
      );
      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getStatusCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getStatus = this.getErrorMessage(err);
        this.loading.getStatus = false;
        return;
      }
    },
    getStatusAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getStatus = this.$t("error.generic_error");
      this.loading.getStatus = false;
    },
    getStatusCompleted(taskContext, taskResult) {
      this.status = taskResult.output;
      this.loading.getStatus = false;
    },
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.host = config.host;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isLetsEncryptCurrentlyEnabled = config.lets_encrypt;
      this.isHttpToHttpsEnabled = config.http2https;
      this.mysql_user_name = config.mysql_user_name;
      this.mysql_user_db = config.mysql_user_db;
      this.mysql_user_pass = config.mysql_user_pass;
      this.mysql_admin_pass = config.mysql_admin_pass;
      this.firstConfig = config.firstConfig;
      this.loading.getConfiguration = false;
      this.create_mysql_user = config.create_mysql_user;
      this.php_upload_max_filesize = config.php_upload_max_filesize;
      this.php_memory_limit = config.php_memory_limit;
      this.phpmyadmin_enabled = config.phpmyadmin_enabled;
      this.PhpVersion = config.php_version;
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);

      let isValidationOk = true;
      if (!this.host) {
        this.error.host = "common.required";

        if (isValidationOk) {
          this.focusElement("host");
        }
        isValidationOk = false;
      }
      if (!this.mysql_admin_pass) {
        this.error.mysql_admin_pass = "common.required";

        if (isValidationOk) {
          this.focusElement("mysql_admin_pass");
        }
        isValidationOk = false;
      }
      if (this.mysql_admin_pass && this.mysql_admin_pass.length < 8) {
        this.error.mysql_admin_pass = "common.required_min_length8";

        if (isValidationOk) {
          this.focusElement("mysql_admin_pass");
        }
        isValidationOk = false;
      }
      if (this.create_mysql_user && !this.mysql_user_name) {
        this.error.mysql_user_name = "common.required";

        if (isValidationOk) {
          this.focusElement("mysql_user_name");
        }
        isValidationOk = false;
      }
      if (this.create_mysql_user && !this.mysql_user_pass) {
        this.error.mysql_user_pass = "common.required";

        if (isValidationOk) {
          this.focusElement("mysql_user_pass");
        }
        isValidationOk = false;
      }
      if (this.create_mysql_user && this.mysql_user_pass.length < 8) {
        this.error.mysql_user_pass = "common.required_min_length8";

        if (isValidationOk) {
          this.focusElement("mysql_user_pass");
        }
        isValidationOk = false;
      }
      if (this.create_mysql_user && !this.mysql_user_db) {
        this.error.mysql_user_db = "common.required";

        if (isValidationOk) {
          this.focusElement("mysql_user_db");
        }
        isValidationOk = false;
      }
      return isValidationOk;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;
      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        if (validationError.details) {
          // show inline error notification with details
          this.validationErrorDetails = validationError.details
            .split("\n")
            .filter((detail) => detail.trim() !== "");
        } else {
          // set i18n error message
          this.error[param] = this.$t("settings." + validationError.error);
          if (!focusAlreadySet) {
            this.focusElement(param);
            focusAlreadySet = true;
          }
        }
      }
    },
    async configureModule() {
      this.error.test_imap = false;
      this.error.test_smtp = false;
      const isValidationOk = this.validateConfigureModule();
      if (!isValidationOk) {
        return;
      }

      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            host: this.host,
            lets_encrypt: this.isLetsEncryptEnabled,
            http2https: this.isHttpToHttpsEnabled,
            mysql_user_name: this.mysql_user_name,
            mysql_user_db: this.mysql_user_db,
            mysql_user_pass: this.mysql_user_pass,
            mysql_admin_pass: this.mysql_admin_pass,
            create_mysql_user: this.create_mysql_user,
            php_upload_max_filesize: this.php_upload_max_filesize,
            php_memory_limit: this.php_memory_limit,
            phpmyadmin_enabled: this.phpmyadmin_enabled,
            php_version: this.PhpVersion,
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;

      // reload configuration
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.maxwidth {
  max-width: 38rem;
}
</style>
