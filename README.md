# UniFi backup file (.unf) / support file (.supp) decryption

It should be trivial to write a script that helps import/export. If anybody wants to contribute, PRs are welcomed.

## Linux

### Requirement

* openssl
* zip

### Some code snippet

```
final Cipher instance = Cipher.getInstance("AES/CBC/NoPadding");
instance.init(2, new SecretKeySpec("bcyangkmluohmars".getBytes(), "AES"), new IvParameterSpec("ubntenterpriseap".getBytes()));
return new CipherInputStream(inputStream, instance);
```

malformed zip files require fixing before unzip

### Database

`db.gz` contains a stream of BSON document for each collections of `ace` database.

You can view its content by `gunzip -c db.gz | bsondump`.

## Windows

### Requirement

* tar
* openssl
* mongodb-database-tools (for bsondump)
