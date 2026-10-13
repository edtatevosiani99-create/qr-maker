from pathlib import Path
import re

gradle = Path("android/app/build.gradle.kts")
text = gradle.read_text()
app_id = "com.edtatevosiani99.qrstudioapp"
text, n1 = re.subn(r'namespace = "[^"]+"', f'namespace = "{app_id}"', text, count=1)
text, n2 = re.subn(r'applicationId = "[^"]+"', f'applicationId = "{app_id}"', text, count=1)
if not n1 or not n2:
    raise SystemExit("Could not locate namespace/applicationId in generated Gradle file")
if 'create("release")' not in text:
    block = '''    signingConfigs {
        create("release") {
            val props = java.util.Properties()
            val propsFile = rootProject.file("key.properties")
            props.load(propsFile.inputStream())
            keyAlias = props.getProperty("keyAlias")
            keyPassword = props.getProperty("keyPassword")
            storeFile = file(props.getProperty("storeFile"))
            storePassword = props.getProperty("storePassword")
        }
    }

'''
    text = text.replace("    buildTypes {", block + "    buildTypes {", 1)
text = re.sub(r'signingConfig = signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.getByName("release")', text)
if 'signingConfig = signingConfigs.getByName("release")' not in text:
    text = text.replace("    buildTypes {", '    buildTypes {\n        getByName("release") { signingConfig = signingConfigs.getByName("release") }', 1)
gradle.write_text(text)
print(f"Configured application ID: {app_id}")
