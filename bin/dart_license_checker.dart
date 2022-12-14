import 'dart:convert';
import 'dart:io';

import 'package:barbecue/barbecue.dart';
import 'package:pana/pana.dart';
import 'package:pana/src/license.dart';
import 'package:path/path.dart';
import 'package:tint/tint.dart';

const possibleLicenseFileNames = [
  // LICENSE
  'LICENSE',
  'LICENSE.md',
  'license',
  'license.md',
  'License',
  'License.md',
  // LICENCE
  'LICENCE',
  'LICENCE.md',
  'licence',
  'licence.md',
  'Licence',
  'Licence.md',
  // COPYING
  'COPYING',
  'COPYING.md',
  'copying',
  'copying.md',
  'Copying',
  'Copying.md',
  // UNLICENSE
  'UNLICENSE',
  'UNLICENSE.md',
  'unlicense',
  'unlicense.md',
  'Unlicense',
  'Unlicense.md',
];

void main(List<String> arguments) async {
  final showTransitiveDependencies =
      arguments.contains('--show-transitive-dependencies');
  final plain = arguments.contains('--plain');
  final pubspecFile = File('pubspec.yaml');

  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml file not found in current directory'.red());
    exit(1);
  }

  final pubspec = Pubspec.parseYaml(pubspecFile.readAsStringSync());

  final packageConfigFile = File('.dart_tool/package_config.json');

  if (!pubspecFile.existsSync()) {
    stderr.writeln(
        '.dart_tool/package_config.json file not found in current directory. You may need to run "flutter pub get" or "pub get"'
            .red());
    exit(1);
  }

  print('Checking dependencies...'.blue());

  final packageConfig = json.decode(packageConfigFile.readAsStringSync());

  final licenses = <String, List<License>>{};

  for (final package in packageConfig['packages']) {
    final name = package['name'];

    if (!showTransitiveDependencies) {
      if (!pubspec.dependencies.containsKey(name)) {
        continue;
      }
    }

    String rootUri = package['rootUri'];
    if (rootUri.startsWith('file://')) {
      if (Platform.isWindows) {
        rootUri = rootUri.substring(8);
      } else {
        rootUri = rootUri.substring(7);
      }
    }

    List<License>? license;

    for (final fileName in possibleLicenseFileNames) {
      final file = File(join(rootUri, fileName));
      if (file.existsSync()) {
        // ignore: invalid_use_of_visible_for_testing_member
        license = await detectLicenseInFile(file, relativePath: file.path);
        break;
      }
    }

    licenses[name] = license ?? [];
  }
  if (plain) {
    printPlain(licenses);
  } else {
    printTable(licenses);
  }

  exit(0);
}

void printTable(Map<String, List<License>> licenses) {
  final rows = licenses
      .map((key, value) => MapEntry(
          key,
          Row(cells: [
            Cell(key, style: CellStyle(alignment: TextAlignment.TopRight)),
            if (licenses.isEmpty)
              Cell('No license file'.grey())
            else
              ...value.map((lic) => Cell(formatLicenseSpdx(lic)))
          ])))
      .values
      .toList();
  print(
    Table(
      tableStyle: TableStyle(border: true),
      header: TableSection(
        rows: [
          Row(
            cells: [
              Cell(
                'Package Name  '.bold(),
                style: CellStyle(alignment: TextAlignment.TopRight),
              ),
              Cell('License'.bold()),
            ],
            cellStyle: CellStyle(borderBottom: true),
          ),
        ],
      ),
      body: TableSection(
        cellStyle: CellStyle(paddingRight: 2),
        rows: rows,
      ),
    ).render(),
  );
}

void printPlain(Map<String, List<License>> rows) {
  for (final row in rows.entries) {
    final licenses = row.value.isNotEmpty
        ? row.value.map((e) => e.spdxIdentifier).join(', ')
        : 'No license file';
    print('${row.key}:$licenses');
  }
}

String formatLicenseName(LicenseFile license) {
  if (license.name == 'unknown') {
    return license.name.red();
  } else if (copyleftOrProprietaryLicenses.contains(license.name)) {
    return license.shortFormatted.red();
  } else if (permissiveLicenses.contains(license.name)) {
    return license.shortFormatted.green();
  } else {
    return license.shortFormatted.yellow();
  }
}

String formatLicenseSpdx(License license) {
  if (license.spdxIdentifier == 'unknown') {
    return license.spdxIdentifier.red();
  } else if (copyleftOrProprietaryLicenses
      .any((str) => str.contains(license.spdxIdentifier))) {
    return license.spdxIdentifier.red();
  } else if (permissiveLicenses
      .any((str) => str.contains(license.spdxIdentifier))) {
    return license.spdxIdentifier.green();
  } else {
    return license.spdxIdentifier.yellow();
  }
}

// TODO LGPL, AGPL, MPL

const permissiveLicenses = [
  'MIT',
  'BSD',
  'BSD-1-Clause',
  'BSD-2-Clause-Patent',
  'BSD-2-Clause-Views',
  'BSD-2-Clause',
  'BSD-3-Clause-Attribution',
  'BSD-3-Clause-Clear',
  'BSD-3-Clause-LBNL',
  'BSD-3-Clause-Modification',
  'BSD-3-Clause-No-Military-License',
  'BSD-3-Clause-No-Nuclear-License-2014',
  'BSD-3-Clause-No-Nuclear-License',
  'BSD-3-Clause-No-Nuclear-Warranty',
  'BSD-3-Clause-Open-MPI',
  'BSD-3-Clause',
  'BSD-4-Clause-Shortened',
  'BSD-4-Clause-UC',
  'BSD-4-Clause',
  'BSD-Protection',
  'BSD-Source-Code',
  'Apache',
  'Apache-1.0',
  'Apache-1.1',
  'Apache-2.0',
  'Unlicense',
];

const copyleftOrProprietaryLicenses = [
  'GPL',
  'GPL-1.0',
  'GPL-2.0',
  'GPL-3.0',
];
