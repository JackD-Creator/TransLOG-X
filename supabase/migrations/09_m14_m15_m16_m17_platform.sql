-- =============================================================================
-- TransLOG-X  |  09_m14_m15_m16_m17_platform.sql
-- M14: User Management & Security (sessions, security events)
-- M15: Communication & Collaboration (notifications, vendor portal, disputes)
-- M16: Mobile Application (device registration, offline sync queue)
-- M17: Integration & Platform (api connections, webhooks, integration logs)
-- =============================================================================


-- =============================================================================
-- M14: USER MANAGEMENT & SECURITY
-- =============================================================================

CREATE TABLE user_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  user_id         UUID NOT NULL REFERENCES profiles(id),

  session_token   TEXT NOT NULL UNIQUE,
  device_type     TEXT DEFAULT 'web'
                  CHECK (device_type IN ('web','mobile_ios','mobile_android','api')),
  device_name     TEXT,
  ip_address      INET,
  user_agent      TEXT,
  location        TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ NOT NULL,
  revoked_at      TIMESTAMPTZ,
  revoke_reason   TEXT
);

CREATE TABLE security_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID REFERENCES tenants(id),
  user_id       UUID REFERENCES profiles(id),

  event_type    TEXT NOT NULL,  -- 'login','logout','login_failed','mfa_challenged','password_reset','session_revoked','permission_denied','suspicious_access'
  severity      priority_level NOT NULL DEFAULT 'low',
  status        TEXT DEFAULT 'info'
                CHECK (status IN ('info','warning','critical','resolved')),

  ip_address    INET,
  user_agent    TEXT,
  location      TEXT,
  details       JSONB NOT NULL DEFAULT '{}',

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user   ON user_sessions(user_id, last_active_at DESC);
CREATE INDEX idx_sessions_tenant ON user_sessions(tenant_id);
CREATE INDEX idx_sec_events_tenant ON security_events(tenant_id, created_at DESC);
CREATE INDEX idx_sec_events_user   ON security_events(user_id, created_at DESC);

ALTER TABLE user_sessions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_events  ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON user_sessions
  FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id());
CREATE POLICY tenant_isolation ON security_events
  FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id());


-- =============================================================================
-- M15: COMMUNICATION & COLLABORATION
-- =============================================================================

CREATE TABLE notification_templates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID REFERENCES tenants(id),  -- NULL = system template

  code            TEXT NOT NULL,
  name            TEXT NOT NULL,
  channel         notification_channel NOT NULL,
  subject         TEXT,
  body_template   TEXT NOT NULL,    -- Handlebars/Mustache template
  variables       TEXT[] DEFAULT '{}',  -- expected variable names

  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (code, channel)
);

CREATE TABLE notifications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  recipient_id    UUID REFERENCES profiles(id),
  recipient_email TEXT,
  recipient_phone TEXT,

  template_id     UUID REFERENCES notification_templates(id),
  channel         notification_channel NOT NULL,
  status          notification_status NOT NULL DEFAULT 'pending',

  subject         TEXT,
  body            TEXT NOT NULL,

  -- Source event
  source_type     TEXT,   -- 'po','grn','invoice','bpjs_claim','stock_alert','capa'
  source_id       UUID,

  sent_at         TIMESTAMPTZ,
  delivered_at    TIMESTAMPTZ,
  read_at         TIMESTAMPTZ,
  failed_reason   TEXT,
  retry_count     INT NOT NULL DEFAULT 0,

  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE vendor_messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  supplier_id     UUID NOT NULL REFERENCES suppliers(id),

  thread_id       UUID,             -- group messages into threads
  direction       TEXT NOT NULL CHECK (direction IN ('outbound','inbound')),
  channel         TEXT NOT NULL DEFAULT 'portal'
                  CHECK (channel IN ('portal','email','whatsapp','sms')),

  subject         TEXT,
  body            TEXT NOT NULL,

  ref_type        TEXT,   -- 'rfq','po','invoice','dispute'
  ref_id          UUID,

  sent_by         UUID REFERENCES profiles(id),
  sent_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at         TIMESTAMPTZ,

  attachments     TEXT[] DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE dispute_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  supplier_id     UUID REFERENCES suppliers(id),

  dispute_number  TEXT NOT NULL,
  type            TEXT NOT NULL
                  CHECK (type IN ('invoice','payment','delivery','quality','bpjs','contract','other')),
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','negotiating','escalated','resolved','closed','arbitration')),

  ref_type        TEXT,
  ref_id          UUID,
  ref_number      TEXT,

  title           TEXT NOT NULL,
  description     TEXT NOT NULL,
  claimed_amount  NUMERIC(18, 2),
  settled_amount  NUMERIC(18, 2),

  raised_by       UUID REFERENCES profiles(id),
  assigned_to     UUID REFERENCES profiles(id),
  resolved_at     TIMESTAMPTZ,
  resolution      TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, dispute_number)
);

CREATE INDEX idx_notif_tenant    ON notifications(tenant_id, created_at DESC);
CREATE INDEX idx_notif_recipient ON notifications(recipient_id) WHERE read_at IS NULL;
CREATE INDEX idx_vendor_msg_sup  ON vendor_messages(supplier_id);
CREATE INDEX idx_disputes_tenant ON dispute_records(tenant_id, status);

CREATE TRIGGER trg_notif_tmpl_updated_at
  BEFORE UPDATE ON notification_templates
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_disputes_updated_at
  BEFORE UPDATE ON dispute_records
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'notification_templates','notifications','vendor_messages','dispute_records'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;


-- =============================================================================
-- M16: MOBILE APPLICATION
-- =============================================================================

CREATE TABLE mobile_devices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  user_id         UUID NOT NULL REFERENCES profiles(id),

  device_id       TEXT NOT NULL UNIQUE,   -- hardware/app unique ID
  device_name     TEXT,
  platform        TEXT NOT NULL CHECK (platform IN ('ios','android','web')),
  app_version     TEXT,
  os_version      TEXT,

  push_token      TEXT,           -- FCM / APNs token
  push_enabled    BOOLEAN NOT NULL DEFAULT FALSE,

  last_active_at  TIMESTAMPTZ,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE offline_sync_queue (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  device_id       TEXT NOT NULL,
  user_id         UUID NOT NULL REFERENCES profiles(id),

  operation       TEXT NOT NULL CHECK (operation IN ('create','update','delete')),
  resource_type   TEXT NOT NULL,    -- 'stock_count_line','picking_line','grn_line','gps_event'
  resource_id     UUID,
  payload         JSONB NOT NULL,

  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','synced','conflict','failed')),
  conflict_data   JSONB,
  synced_at       TIMESTAMPTZ,
  error_message   TEXT,
  retry_count     INT NOT NULL DEFAULT 0,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mobile_devices_user  ON mobile_devices(user_id);
CREATE INDEX idx_offline_sync_device  ON offline_sync_queue(device_id, status);
CREATE INDEX idx_offline_sync_pending ON offline_sync_queue(tenant_id, status)
  WHERE status = 'pending';

CREATE TRIGGER trg_mobile_devices_updated_at
  BEFORE UPDATE ON mobile_devices
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY['mobile_devices','offline_sync_queue'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;


-- =============================================================================
-- M17: INTEGRATION & PLATFORM
-- =============================================================================

CREATE TABLE api_connections (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  name            TEXT NOT NULL,
  provider        TEXT NOT NULL,   -- 'bpjs','bpom','snap','satusehat','lkpp','coretax','dukcapil','privy','ojk_slik'
  endpoint_url    TEXT,
  environment     TEXT NOT NULL DEFAULT 'production'
                  CHECK (environment IN ('sandbox','staging','production')),
  status          TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active','inactive','error','maintenance')),

  -- Credentials (encrypted at rest by Supabase)
  client_id       TEXT,
  client_secret   TEXT,           -- store hashed/encrypted
  api_key         TEXT,
  access_token    TEXT,
  token_expires_at TIMESTAMPTZ,
  refresh_token   TEXT,

  config          JSONB NOT NULL DEFAULT '{}',
  last_connected_at TIMESTAMPTZ,
  last_error      TEXT,
  error_count     INT NOT NULL DEFAULT 0,

  created_by      UUID REFERENCES profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (tenant_id, provider, environment)
);

CREATE TABLE webhook_configs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),

  name            TEXT NOT NULL,
  url             TEXT NOT NULL,
  secret          TEXT,            -- HMAC secret for signature verification
  events          TEXT[] NOT NULL, -- ['po.approved','invoice.paid','bpjs_claim.rejected']
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  retry_count     INT NOT NULL DEFAULT 3,
  timeout_ms      INT NOT NULL DEFAULT 5000,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE integration_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID REFERENCES tenants(id),
  connection_id   UUID REFERENCES api_connections(id),

  direction       TEXT NOT NULL CHECK (direction IN ('inbound','outbound')),
  provider        TEXT NOT NULL,
  endpoint        TEXT,
  method          TEXT,

  request_body    JSONB,
  response_body   JSONB,
  http_status     INT,
  duration_ms     INT,

  status          TEXT NOT NULL DEFAULT 'success'
                  CHECK (status IN ('success','error','timeout','retrying')),
  error_message   TEXT,
  correlation_id  TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE webhook_deliveries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES tenants(id),
  webhook_id      UUID NOT NULL REFERENCES webhook_configs(id),

  event_type      TEXT NOT NULL,
  payload         JSONB NOT NULL,
  http_status     INT,
  response_body   TEXT,
  duration_ms     INT,
  attempt_no      INT NOT NULL DEFAULT 1,

  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','delivered','failed','retrying')),

  delivered_at    TIMESTAMPTZ,
  next_retry_at   TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_api_conn_tenant    ON api_connections(tenant_id);
CREATE INDEX idx_int_logs_tenant    ON integration_logs(tenant_id, created_at DESC);
CREATE INDEX idx_int_logs_provider  ON integration_logs(provider, created_at DESC);
CREATE INDEX idx_wh_deliveries      ON webhook_deliveries(tenant_id, status);

CREATE TRIGGER trg_api_conn_updated_at
  BEFORE UPDATE ON api_connections
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_webhook_updated_at
  BEFORE UPDATE ON webhook_configs
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'api_connections','webhook_configs','integration_logs','webhook_deliveries'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (is_service_role() OR tenant_id = current_tenant_id())',
      'tenant_isolation', t
    );
  END LOOP;
END $$;

-- =============================================================================
-- END  09_m14_m15_m16_m17_platform.sql
-- =============================================================================
