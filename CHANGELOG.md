**3.0.0**
* Calculate unique value by multiplying in exact total rather closest power of
  2 (bitwise).

  INCOMPATIBLE: when your totals are not powers of 2. If you already depend
                on previous values of this gem, change your values to the
                closest power of 2.

For example:

```ruby
unique_by client_id: 500
```

Should be:

```ruby
unique_by client_id: 512
```

* Allow passing `:primary_key` explicitly.

  MINOR INCOMPATIBLE: if your group was named `primary_key`.

**2.1.0**
* Remove useless finder methods, you should create your own based on the group.

  MINOR INCOMPATIBLE: if you used the finder methods.
* Using `generate_method` gem, which means generated methods are 'inherited'
  instead of defined in the class itself.

  MINOR INCOMPATIBLE: when expected to override your methods.

**2.0.0**
* MINOR INCOMPATIBLE: key-value arguments instead of totals/bits.

**1.0.0**
* First stable version.