# Rollbacks

If you have a problems after a [deployment](deployment.md), you can rollback
to the previous version of the app.

1. SSH into the server.

2. Check the docker images to see the previous version of the app:

   ```console
   docker images torrust/tracker
   REPOSITORY        TAG       IMAGE ID       CREATED          SIZE
   torrust/tracker   develop   b081a7499542   19 minutes ago   133MB
   torrust/tracker   <none>    7dbdad453cf3   6 hours ago      133MB
   ```

3. Tag the previous version of the app with a new name (e.g. `rollback`):

   ```console
   docker tag 7dbdad453cf3 torrust/tracker:rollback
   ```

   This command tags the image with ID `7dbdad453cf3` as `torrust/tracker:rollback`.

   ```console
     docker images torrust/tracker
       REPOSITORY        TAG        IMAGE ID       CREATED          SIZE
       torrust/tracker   develop    b081a7499542   21 minutes ago   133MB
       torrust/tracker   rollback   7dbdad453cf3   6 hours ago      133MB
   ```

   The `rollback` tag now points to the previous version of the app.

4. Edit the `compose.yaml` file to use the new tag:

   Change the line:

   ```yaml
   image: torrust/tracker:develop
   ```

   to:

   ```yaml
   image: torrust/tracker:rollback
   ```

5. Run the following command to start the previous version of the app:

   ```console
   docker compose up --build --detach
   ```

6. Check the logs of the tracker container to see if everything is working:

   ```console
   ./share/bin/tracker-filtered-logs.sh
   ```
