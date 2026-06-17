export interface SecurityPermission {
  code: string;
  module: string;
  description: string;
}

export interface SecurityRole {
  code: string;
  name: string;
  description: string;
  permissions: SecurityPermission[];
}

export interface SecurityUser {
  id: string;
  username: string;
  displayName: string;
  firstName: string;
  lastName: string;
  email: string;
  enabled: boolean;
  roleCodes: string[];
}

export interface SecurityUserRequest {
  username: string;
  firstName: string;
  lastName: string;
  email: string;
  enabled: boolean;
  roleCodes: string[];
}
