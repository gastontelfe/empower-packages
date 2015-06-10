EmPOWER packages for OpenWrt
===========

Setup in OpenWrt:

```
  $: cd $TOPDIR
  $: echo 'src-git empower git@github.com:rriggio/empower-packages.git' >> feeds.conf.default
  $: ./scripts/feeds update empower
  $: ./scripts/feeds install -a -p empower
  $: make menuconfig
  $: select Network -> empower-agent
```

