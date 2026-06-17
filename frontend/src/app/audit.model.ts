export type AuditRevisionType = 'ADD' | 'MOD' | 'DEL';
export type AuditValues = Record<string, unknown>;

export interface AuditRevision {
  entityName: string;
  entityId: number;
  revision: number;
  revisionType: AuditRevisionType;
  changedAt: string;
  username: string | null;
  previousValues: AuditValues;
  currentValues: AuditValues;
}

export interface AuditFieldChange {
  field: string;
  previousValue: unknown;
  currentValue: unknown;
}
