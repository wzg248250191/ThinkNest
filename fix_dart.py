import re

with open(r'd:\FlutterItem\think_nest\lib\common\values\course_introduces.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We want to replace \蝎子 with \\蝎子, but wait, it's easier to just do it generally.
# We have lines like: '沙漠探险之旅': '<style>...【单击】蜥蜴\蝎子\兔子，逃入洞穴。...'
# The \ is followed by a Chinese character, which causes the warning.
# Let's replace any single backslash that is not followed by n, r, t, ', ", \ with double backslash.
# But actually, in the string, any \ not meant to be an escape should be \\.
# The only escapes we added were \n and \'.
# So if we find \ that is NOT followed by n, ', or \, we can replace it.

fixed_content = re.sub(r'\\([^n\'\\])', r'\\\\\1', content)

with open(r'd:\FlutterItem\think_nest\lib\common\values\course_introduces.dart', 'w', encoding='utf-8') as f:
    f.write(fixed_content)

print('Done')
