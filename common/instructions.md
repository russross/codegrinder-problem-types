1. Replace each stepper invocation:

   ```make
   python3 lib/stepper
   ```

   with:

   ```make
   sh lib/stepper -- $(STEPPER_CMD)
   ```

2. Keep `STEPPER_CMD` and existing exported `STEPPER_*` settings. Use a positive **whole number of seconds** for `STEPPER_TIMEOUT`.

3. In grade recipes, remove the correctly named report:

   ```make
   @rm -f test_detail.xml
   ```

4. For the SQL Makefile, use portable `sed` capture groups and escape `$` for Make:

   ```make
   STEPPER_CMD=sqlite3 --batch database.db ".read @INPUT@"
   STEPPER_INPUT_TRANSFORM=s/outputs\/\(.*\)\.transcript$$/\1.sql/
   ```

   Keep exporting `STEPPER_INPUT_TRANSFORM`. The quoted `.read @INPUT@` remains one argument.

Install the new shell [lib/stepper](/tmp/test-problem/lib/stepper) alongside each updated Makefile.
