# Dataservices: Getting Docker Running (on an M1 Mac, ca. 2023)

These are edits which should be made locally and never pushed up.

1. Fiona doesn't work on an M1, and we can work without it, but it IS required
   on an Intel Mac

```
# in config/common/requirements.txt:

-fiona==1.8.13.post1
+# fiona==1.8.13.post1
```

2. GPG was problematic on my install. We nixed it.

```
# in config/docker/Dockerfile:

-WORKDIR /root/data_services/config/docker/scripts
-RUN mkdir /root/.gnupg/ && \
-    python gpg_keys.py
+# WORKDIR /root/data_services/config/docker/scripts
+# RUN mkdir /root/.gnupg/ && \
+#     python gpg_keys.py
```


3. GPG part 2:

```
in config/docker/scripts/gpg_keys.py:

-    f'{home_dir}/data_services/config/aws/dataservices.gpg.secret.key',
+    #f'{home_dir}/data_services/config/aws/dataservices.gpg.secret.key',
```
