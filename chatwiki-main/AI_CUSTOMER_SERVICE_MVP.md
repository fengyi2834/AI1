# AI Customer Service MVP

This repository already contains the core capabilities needed for an AI customer service system. The MVP path after this update is:

1. Start the backend and database normally.
2. In the admin console, create a chat robot and configure a model provider.
3. Bind a knowledge base or FAQ library to that robot.
4. Open the public customer service portal with:

```text
/?admin_user_id=<your_admin_user_id>
```

5. If there is only one available chat robot, the portal will jump directly into the chat page.
6. If there are multiple chat robots, the portal will show a selectable customer service entry page first.

## What changed for MVP

- The public client-side robot list now returns only chat-type robots, so workflow robots do not appear in the customer portal by mistake.
- The public portal now has a usable home page in both the PC and mobile frontends.
- The router guard no longer blocks the public home page before the user can choose a robot.

## Expected MVP flow

1. Customer opens the public portal.
2. Customer selects a service robot.
3. Customer enters `/chat` with the selected `robot_key`.
4. The existing chat flow handles welcome message, session creation, streaming responses, and message history.
