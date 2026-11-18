-- Apply manually after backup and inspection of the target MySQL schema.
CREATE TABLE IF NOT EXISTS admin_membership (
  user_id VARCHAR(64) PRIMARY KEY,
  role ENUM('super_admin','botanist','editor') NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_audit_event (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  actor_id VARCHAR(64) NOT NULL,
  action VARCHAR(64) NOT NULL,
  entity_type VARCHAR(64) NOT NULL,
  entity_id VARCHAR(128) NOT NULL,
  before_json JSON NULL,
  after_json JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_entity (entity_type, entity_id, created_at),
  INDEX idx_audit_actor (actor_id, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_content_revision (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  entity_type VARCHAR(64) NOT NULL,
  entity_id VARCHAR(128) NOT NULL,
  payload JSON NOT NULL,
  status ENUM('draft','pending_review','published','rejected') NOT NULL DEFAULT 'draft',
  author_id VARCHAR(64) NOT NULL,
  reviewer_id VARCHAR(64) NULL,
  review_note TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_revision_entity (entity_type, entity_id, status)
) ENGINE=InnoDB;
