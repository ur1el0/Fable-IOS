# Deploy Fable with Render and Neon

This deployment keeps SQLite as the local default and uses Neon PostgreSQL when `FABLE_DATABASE_BACKEND=postgres` is set. `render.yaml` defines a free Render Docker web service, uses the Render-provided port, and checks `/api/v1/health`. Neon holds persistent application data; Render's free web service filesystem is temporary and is used only for a disposable Gutenberg catalog cache.

## Free-tier limits

- Render Free web services sleep after 15 minutes without inbound traffic, take about a minute to wake, and lose local filesystem changes on restart, redeploy, or sleep. They have no persistent disk. Keep user data in Neon.
- Neon Free currently includes 100 compute hours and 1 GB of Postgres storage per project. Compute scales to zero after five idle minutes. If monthly limits are exhausted, Neon suspends compute until the next billing period.
- Select **Free** plans in both dashboards. Do not add a payment method or upgrade a resource if a strict $0 ceiling is required. If a free quota is reached, expect service suspension rather than continued availability.
- A new Neon project starts with an empty Fable schema. Existing local SQLite accounts, shelves, and authored stories are not copied automatically. The public catalog is fetched from its upstream providers.

## Create the Neon database

1. Create a Neon project on the Free plan. Choose **AWS Asia Pacific 1 (Singapore)** to colocate it with the Render service.
2. Open **Connect** for the project's primary branch and database.
3. Enable **Pooled connection** and copy the connection string. It must use TLS (`sslmode=require` or stronger). Treat this URL as a password; do not commit it or send it in chat.

## Create the Render service

1. Push this branch or merge its changes to `main`, then open the Render Dashboard and choose **New → Blueprint**.
2. Connect `ur1el0/Fable-IOS` and choose the branch containing `render.yaml`.
3. Review the service before applying it. Confirm the plan is **Free**, the region is **Singapore**, and the service is named `fable-api`.
4. When Render prompts for unsynced environment values, paste the Neon pooled `DATABASE_URL`. Generate a separate ingestion key in your local terminal with `openssl rand -hex 32`, then provide it as `FABLE_INGESTION_API_KEY`. Never reuse your Neon password for the ingestion key.
5. Apply the Blueprint and wait for the first deploy to pass its health check. Render provides an HTTPS URL such as `https://fable-api.onrender.com`.
6. Open `https://<service-name>.onrender.com/api/v1/health`. It should report `healthy` and `database: connected`.
7. Configure the iOS Release setting `FABLE_API_BASE_URL` as `https://<service-name>.onrender.com/api/v1`.

Render connects the public service through its proxy. The Blueprint trusts forwarded client IP headers from that proxy so per-client rate limits use the real client address. Do not expose the container directly outside Render.

## Optional settings and known limits

- To enable password-reset email, add the existing SMTP settings as Render environment secrets. Render Free blocks outbound SMTP on ports 25, 465, and 587, so the current Gmail SMTP configuration will not send mail from this plan. Use an HTTPS mail API integration or a host that permits SMTP if deployed password recovery is required.
- Provider ingestion endpoints also require `FABLE_INGESTION_API_KEY`; the Blueprint requests it during service setup.
- This setup does not migrate the local SQLite database. If local account or authored-story data must be preserved, export and migrate it before pointing the app at the hosted service.
- Check both providers' usage pages periodically. Render Free web services can sleep, and Neon Free can suspend database compute after its included monthly allowance is used.
