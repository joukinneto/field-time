from pathlib import Path

path = Path('lib/src/presentation/screens/time_records_screen.dart')
text = path.read_text()

text = text.replace(
"  _Destination _destination = _Destination.home;\n",
"  _Destination _destination = _Destination.home;\n  int _managementResetToken = 0;\n",
1,
)

text = text.replace(
"                  onTap: (index) =>\n                      setState(() => _destination = destinations[index]),",
"                  onTap: (index) => _selectDestination(destinations[index]),",
1,
)

text = text.replace(
"                        onSelected: (value) =>\n                            setState(() => _destination = value),",
"                        onSelected: _selectDestination,",
1,
)

text = text.replace(
"    _Destination.management => const SupervisorCenterScreen(),",
"    _Destination.management => SupervisorCenterScreen(\n      key: ValueKey('management-$_managementResetToken'),\n    ),",
1,
)

anchor = "  List<_Destination> _visibleDestinations(SupervisorCenterState pilotState) => [\n"
method = """  void _selectDestination(_Destination destination) {\n    setState(() {\n      _destination = destination;\n      if (destination == _Destination.management) {\n        _managementResetToken += 1;\n      }\n    });\n  }\n\n"""
if method not in text:
    text = text.replace(anchor, method + anchor, 1)

path.write_text(text)
print('Bottom navigation now resets nested Management navigation to its root dashboard.')
