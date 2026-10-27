# Security Findings and Remediation Plan

## Observed findings

The Trivy scan summary recorded:
- 44 high-severity OS-package findings
- 4 high-severity Python-package findings
- 0 critical findings in the displayed summary

The pipeline's Trivy stage was informational and did not block the build.

These results are a record of the scan observed during this project. They do not establish the current vulnerability status of a newly built image.

## Status

Remediation is planned and must not be marked complete until a new scan verifies the outcome.

## Remediation checklist

- [ ] Save the complete Trivy report and identify CVEs, package versions, and available fixes.
- [ ] Review fixability, severity, and applicability of each finding.
- [ ] Update the base image and compatible Python dependencies where appropriate.
- [ ] Run unit tests after dependency changes.
- [ ] Rebuild the Docker image.
- [ ] Rescan the rebuilt image with Trivy.
- [ ] Compare the new results with the original findings.
- [ ] Document any remaining vulnerabilities and unavailable fixes.
- [ ] Consider an agreed CI policy for critical and high-severity findings.
- [ ] Consider generating and retaining a software bill of materials (SBOM).

## Evidence required before closing remediation

Attach or retain the new scan output, image tag or digest, test results, and a summary of resolved and outstanding findings.

Do not describe the image as vulnerability-free unless the claim is appropriately supported by current evidence and scan scope.
