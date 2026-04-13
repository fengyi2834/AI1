# 知识库目录模板（从 xlsx/docx 起步）

适用于“广西亿库光养硅藻环保科技有限公司”AI 客服建设的资料整理结构。

## 目录结构建议
```
kb/
  00_readme.md
  01_company/
    company_profile.md
    qualifications.md
  02_products/
    product_overview.md
    product_specs_table.md
    product_models/
      model_a.md
      model_b.md
  03_pricing/
    pricing_policy.md
    quotation_rules.md
  04_cases/
    case_template.md
    case_001.md
  05_installation/
    installation_flow.md
    maintenance.md
  06_after_sales/
    warranty.md
    service_scope.md
  07_faq/
    faq_general.md
    faq_installation.md
    faq_quality.md
  08_policy/
    compliance_statement.md
    privacy_policy.md
  09_contact/
    contact_info.md
    lead_capture.md
  99_changes/
    change_log.md
```

## 从 xlsx/docx 生成知识块的最小流程
1. `docx` 提取为纯文本或 Markdown，按主题拆分成短段落。
2. `xlsx` 拆成 “问题-答案 / 参数表 / 规格说明” 三类内容。
3. 每个文件控制在 300-800 字左右，标题清晰，避免超长段落。

## FAQ 模板（建议统一格式）
```
Q: 光养硅藻板适用哪些场景？
A: 适用于...

Q: 是否支持定制尺寸？
A: 支持...
```

## 切片建议
- 每段 200-500 字，标题必须明确描述主题。
- 表格类内容拆成“字段说明 + 示例行”。
- 不确定的描述用 “需确认/建议联系人工” 提示，避免 AI 编造。
