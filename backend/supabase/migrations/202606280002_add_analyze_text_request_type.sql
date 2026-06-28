-- 扩展 usage_records 表的 request_type 检查约束，支持 analyze_text
alter table public.usage_records
  drop constraint if exists usage_records_request_type_check,
  add constraint usage_records_request_type_check
    check (request_type in ('analyze_screenshot', 'analyze_text'));
