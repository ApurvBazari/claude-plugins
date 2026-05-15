# Payments — Provider: {{payments.provider}}

## Billing
- Provider: {{payments.provider}}
- Billing model: {{payments.billingModel}}

## Customer experience
- Customer portal: {{payments.customerPortal}}
- Refund flow: {{payments.refundFlow}}

## Operations
- Tax handling: {{payments.taxHandling}}
- Dunning strategy: {{payments.dunning}}
- Webhook strategy: {{payments.webhookStrategy}}
- Fraud prevention: {{payments.fraudPrevention}}

## Compliance
- PCI scope: {{payments.compliance.pciScope}}
- SCA / 3DS required: {{payments.compliance.sca}}
- Other regulatory regimes:
{{#each payments.compliance.regulatory}}  - {{this}}
{{/each}}

## Currencies & locales
{{#each payments.currencyLocale}}- {{this}}
{{/each}}

## Risks
{{#each payments.qRisks}}- {{this}}
{{/each}}
