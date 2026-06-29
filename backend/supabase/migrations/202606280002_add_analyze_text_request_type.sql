-- =============================================
-- 迁移脚本：扩展 usage_records 请求类型
-- 创建时间: 2026-06-28
-- 描述: 在 usage_records 表中新增 analyze_text 请求类型支持
-- =============================================

-- 扩展 usage_records 表的 request_type 检查约束，支持 analyze_text
-- 原有类型: analyze_screenshot (截图分析)
-- 新增类型: analyze_text (文本分析)
alter table public.usage_records
  -- 先删除旧的约束（如果存在）
  drop constraint if exists usage_records_request_type_check,
  -- 添加新的约束，包含原有类型和新类型
  add constraint usage_records_request_type_check
    check (request_type in ('analyze_screenshot', 'analyze_text'));
