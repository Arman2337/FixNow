# Version-controlled Git hooks

Activate these hooks after cloning:

```bash
git config core.hooksPath .githooks
```

The `pre-commit` hook prevents commits while `main` is checked out. Hosting branch protection must enforce the same policy centrally because local hooks can be absent or bypassed.
