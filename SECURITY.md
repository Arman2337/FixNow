# Security Policy

## Reporting a vulnerability

Do not create a public issue for a suspected vulnerability. Report it privately to the repository owners through the private security reporting channel configured on the Git hosting platform. If no private channel is available, contact an owner directly and share only the minimum reproduction details needed.

Include the affected component, impact, reproduction steps, and any known mitigation. Do not include real customer data or active credentials.

## Supported versions

The project has not shipped a supported release. This policy will be updated when versioned releases begin.

## Secret exposure

If a secret is committed, treat it as compromised: revoke or rotate it first, then remove it from the repository and history using an approved incident process. Deleting the visible file alone is not sufficient.
