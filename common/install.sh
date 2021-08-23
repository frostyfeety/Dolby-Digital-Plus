osp_detect() {
  case $1 in
    *.conf) SPACES=$(sed -n "/^output_session_processing {/,/^}/ {/^ *music {/p}" $1 | sed -r "s/( *).*/\1/")
            EFFECTS=$(sed -n "/^output_session_processing {/,/^}/ {/^$SPACES\music {/,/^$SPACES}/p}" $1 | grep -E "^$SPACES +[A-Za-z]+" | sed -r "s/( *.*) .*/\1/g")
            for EFFECT in ${EFFECTS}; do
              SPACES=$(sed -n "/^effects {/,/^}/ {/^ *$EFFECT {/p}" $1 | sed -r "s/( *).*/\1/")
              [ "$EFFECT" != "atmos" ] && sed -i "/^effects {/,/^}/ {/^$SPACES$EFFECT {/,/^$SPACES}/ s/^/#/g}" $1
            done;;
     *.xml) EFFECTS=$(sed -n "/^ *<postprocess>$/,/^ *<\/postprocess>$/ {/^ *<stream type=\"music\">$/,/^ *<\/stream>$/ {/<stream type=\"music\">/d; /<\/stream>/d; s/<apply effect=\"//g; s/\"\/>//g; p}}" $1)
            for EFFECT in ${EFFECTS}; do
              [ "$EFFECT" != "atmos" ] && sed -ri "s/^( *)<apply effect=\"$EFFECT\"\/>/\1<\!--<apply effect=\"$EFFECT\"\/>-->/" $1
            done;;
  esac
}

# Tell user aml is needed if applicable
FILES=$(find $NVBASE/modules/*/system $MODULEROOT/*/system -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml" 2>/dev/null)
if [ ! -z "$FILES" ] && [ ! "$(echo $FILES | grep '/aml/')" ]; then
  ui_print " "
  ui_print "   ! Conflicting audio mod found!"
  ui_print "   ! You will need to install !"
  ui_print "   ! Audio Modification Library !"
  sleep 3
fi

# Lib fix for pixel 2's, 3's, and essential phone
if $LIBWA; then
  ui_print "   Applying lib workaround..."
  if [ -f $ORIGDIR/system/lib/libstdc++.so ] && [ ! -f $ORIGDIR/vendor/lib/libstdc++.so ]; then
    cp_ch $ORIGDIR/system/lib/libstdc++.so $MODPATH/system/vendor/lib/libstdc++.so
  elif [ -f $ORIGDIR/vendor/lib/libstdc++.so ] && [ ! -f $ORIGDIR/system/lib/libstdc++.so ]; then
    cp_ch $ORIGDIR/vendor/lib/libstdc++.so $MODPATH/system/lib/libstdc++.so
  fi
fi

# Extract Module
tar -xf $MODPATH/system.tar.xz -C $MODPATH 2>/dev/null
[ ! -f $MODPATH/system/etc/ds1-default.xml ] && { ui_print "! Unable to extract mod file !"; exit 1; }

tar -xf $MODPATH/custom.tar.xz -C $MODPATH 2>/dev/null
[ ! -f $MODPATH/custom/DsUI.apk ] && { ui_print "! Unable to extract app archive file !"; exit 1; }

cp_ch $MODPATH/custom/DsUI.apk $MODPATH/system/priv-app/DsUI/DsUI.apk
# App installation for oreo+
if [ $API -ge 26 ]; then
    cp -f $MODPATH/system/priv-app/DsUI/DsUI.apk $MODPATH/DsUI.apk
    ui_print "   Install manually after booting"
    sleep 2
fi

ui_print "   Patching existing audio_effects files..."
CFGS="$(find /system /vendor -type f -name "*audio_effects*.conf" -o -name "*audio_effects*.xml")"
for OFILE in ${CFGS}; do
  FILE="$MODPATH$(echo $OFILE | sed "s|^/vendor|/system/vendor|g")"
  cp_ch -n $ORIGDIR$OFILE $FILE
  osp_detect $FILE
  case $FILE in
    *.conf) sed -i "/dsplus {/,/}/d" $FILE
            sed -i "s/^effects {/effects {\n  dsplus { #$MODID\n    library dsplus\n    uuid 9d4921da-8225-4f29-aefa-39537a04bcaa\n  } #$MODID/g" $FILE
            sed -i "s/^libraries {/libraries {\n  dsplus { #$MODID\n    path $LIBPATCH\/lib\/soundfx\/libdseffect.so\n  } #$MODID/g" $FILE;;
    *.xml) sed -i "/dsplus/d" $FILE
           sed -i "/<libraries>/ a\        <library name=\"dsplus\" path=\"libdseffect.so\"\/><!--$MODID-->" $FILE
           sed -i "/<effects>/ a\        <effect name=\"dsplus\" library=\"dsplus\" uuid=\"9d4921da-8225-4f29-aefa-39537a04bcaa\"\/><!--$MODID-->" $FILE;;
  esac
done
