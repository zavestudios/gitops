# Observability Alert Routing Verification

## Purpose

Define the current Formation verification path for Grafana and Alertmanager
alert routing without creating synthetic incidents or requiring destructive
runtime changes.

## Current Posture

During Formation, Grafana alerting and Alertmanager UI visibility are the
minimum accepted operator surface.

The current intentional routing posture is default-only until a durable
operator notification target is chosen and represented in Git. A future
notification route must declare:

- contact point type
- destination ownership
- secret source
- notification policy matchers
- non-production test procedure

Do not add ad hoc contact points through the Grafana UI as the durable
configuration path.

## Non-Destructive Verification

Use Grafana through the approved operator access path.

1. Open Grafana.
2. Navigate to Alerting -> Alert rules.
3. Confirm datasource-managed alert rules are visible.
4. Navigate to Alerting -> Contact points.
5. Confirm the current contact point inventory.
6. Navigate to Alerting -> Notification policies.
7. Confirm the default policy tree is visible.
8. Confirm whether any Zave-specific contact point or notification policy
   exists.

Expected Formation result:

- alert rules are visible
- Contact points and Notification policies pages load
- default-only routing is acceptable if no Git-managed notification target has
  been selected

## Follow-Up Trigger

Create a follow-up implementation issue when a real operator notification
target is chosen.

That implementation should configure routing through Git-managed values or
manifests and include a non-production test alert path.
