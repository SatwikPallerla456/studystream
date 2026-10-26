#!/usr/bin/env python3
"""Rebuild the local Graphify map without running the application or its tests.

Run with the interpreter recorded in graphify-out/.graphify_python. Document and
image extraction is retained in semantic-extraction.json; this script refreshes
structural code, schema/channel adapters, inventories, and generated outputs.
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
import wave
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'graphify-out'


def identity(value: str) -> str:
    return re.sub(r'[^a-z0-9]+', '_', value.lower()).strip('_')


def file_id(path: Path) -> str:
    return identity(path.relative_to(ROOT).with_suffix('').as_posix())


def inventory_and_adapters(ast: dict) -> tuple[dict, dict]:
    from graphify.detect import _is_sensitive
    nodes, edges = [], []
    ids = {n['id'] for n in ast['nodes']}
    files = {}
    for n in ast['nodes']:
        src = n.get('source_file')
        # Reuse AST file IDs, including extension-qualified IDs for .h/.m
        # siblings. Inventing a stem-only inventory ID drops channel edges when
        # Graphify reconciles those two real files during graph construction.
        if src and (n.get('source_location') is None or n.get('label') == Path(src).name):
            files.setdefault((ROOT / src).resolve(), n['id'])
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    candidates = {ROOT / name for name in tracked if name}
    candidates.add(Path(__file__).resolve())
    detected = json.loads((OUT / '.graphify_detect.json').read_text())
    candidates.update(Path(f) for group in detected['files'].values() for f in group)
    candidates.update(Path(f) for f in detected.get('unclassified', []))
    evidence = []
    evidence_root = ROOT / '.verification'
    if evidence_root.exists():
        for path in sorted(evidence_root.rglob('*')):
            if path.is_file() and not path.is_symlink() and not _is_sensitive(path):
                evidence.append({'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size,
                                 'mode': 'inventory_only'})
    records = []

    def node(nid, label, path=None, kind='concept', **attrs):
        if nid not in ids:
            nodes.append({'id': nid, 'label': label, 'file_type': kind,
                          'source_file': str(path) if path else None,
                          'source_location': None, '_origin': 'semantic', **attrs})
            ids.add(nid)
        return nid

    def edge(a, b, relation, path, **attrs):
        edges.append({'source': a, 'target': b, 'relation': relation,
                      'confidence': 'EXTRACTED', 'confidence_score': 1.0,
                      'source_file': str(path), 'source_location': None,
                      'weight': 1.0, '_origin': 'semantic', **attrs})

    platform_files = defaultdict(list)
    for path in sorted(candidates):
        if not path.is_file() or path.is_symlink() or _is_sensitive(path):
            continue
        rel = path.relative_to(ROOT).as_posix()
        nid = files.get(path) or node(file_id(path), path.name, path, 'document', extraction_mode='inventory')
        files[path] = nid
        category = rel.split('/')[0] if '/' in rel else 'project'
        platform_files[category].append(nid)
        records.append({'path': rel, 'bytes': path.stat().st_size,
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'node_id': nid,
                        'mode': 'structural' if any(n.get('source_file') == rel for n in ast['nodes']) else 'semantic_or_inventory'})
    for category, members in platform_files.items():
        nid = node('project_area_' + identity(category), category + ' files')
        for member in members:
            path = ROOT / next(r['path'] for r in records if r['node_id'] == member)
            edge(nid, member, 'contains', path)

    schemas = {}
    for rel in ('lib/data/db/app_database.dart', 'lib/data/indexer/library_source_store.dart',
                'lib/domain/catalog/catalog_identity_store.dart'):
        path = ROOT / rel
        text = path.read_text()
        definitions = [(m.group(1), m.group(2), m.start()) for m in re.finditer(
            r'CREATE TABLE IF NOT EXISTS\s+(\w+)\s*\((.*?)\)(?:[\'\"]|\s*\)\s*\))', text, re.S)]
        definitions += [(m.group(1), m.group(2), m.start()) for m in re.finditer(
            r"'([a-z_]+)'\s*:\s*'([^'\n]*\bPRIMARY KEY[^'\n]*)'", text)]
        for name, ddl, offset in definitions:
            sid = node('schema_' + name, name + ' table', path, source_location='L' + str(text[:offset].count('\n') + 1),
                       schema_definition=ddl, extraction_mode='sql_literal')
            schemas[name] = (sid, ddl, path)
            edge(files[path], sid, 'defines_schema', path)
        for m in re.finditer(r'class (\w+) extends Table\s*\{(.*?)\n\}', text, re.S):
            name = re.sub(r'(?<!^)(?=[A-Z])', '_', m[1]).lower()
            columns = re.findall(r'\b(?:\w+Column) get (\w+)', m[2])
            sid = node('schema_' + name, name + ' table', path, columns=columns, extraction_mode='drift_declaration')
            schemas[name] = (sid, m[2], path)
            edge(files[path], sid, 'defines_schema', path)
    for name, (sid, definition, path) in schemas.items():
        for table_class in re.findall(r'\.references\(\s*(\w+)', definition):
            target = re.sub(r'(?<!^)(?=[A-Z])', '_', table_class).lower()
            if target in schemas: edge(sid, schemas[target][0], 'foreign_key', path)
        for target in re.findall(r'REFERENCES\s+(\w+)\s*\(', definition, re.I):
            if target in schemas:
                edge(sid, schemas[target][0], 'foreign_key', path)

    channels = defaultdict(list)
    for path, fid in list(files.items()):
        if path.suffix not in {'.dart', '.swift', '.kt', '.cpp', '.cc', '.h', '.m', '.mm', '.py', '.sh'}:
            continue
        text = path.read_text(errors='replace')
        if path.suffix == '.dart':
            # Derive lexical ownership without interpreting dynamic Dart calls.
            # Preserve line counts while hiding braces in comments and strings.
            literal_pattern = re.compile(r'"""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27|/\*[\s\S]*?\*/|//[^\n]*')
            masked = literal_pattern.sub(lambda m: ''.join('\n' if c == '\n' else ' ' for c in m.group()), text)
            file_nodes = [n for n in ast['nodes'] if n.get('source_file') == path.relative_to(ROOT).as_posix()]
            for declaration in re.finditer(r'\b(?:class|mixin|enum)\s+(\w+)[^{;]*\{', masked):
                owner_name = declaration[1]
                owner = next((n for n in file_nodes if n.get('label') == owner_name), None)
                if owner is None: continue
                start = declaration.end() - 1
                depth, end = 1, start + 1
                while end < len(masked) and depth:
                    depth += (masked[end] == '{') - (masked[end] == '}')
                    end += 1
                first_line = masked[:start].count('\n') + 1
                last_line = masked[:end].count('\n') + 1
                for member in file_nodes:
                    location = str(member.get('source_location') or '')
                    line = re.fullmatch(r'L(\d+)', location)
                    if line and first_line < int(line[1]) <= last_line and member['id'] != owner['id']:
                        edge(owner['id'], member['id'], 'contains_member', path, source_location=location)
            for match in re.finditer(r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''', text, re.M):
                uri = match[1]
                target = ((ROOT / 'lib' / uri.removeprefix('package:study_stream/')) if uri.startswith('package:study_stream/') else (path.parent / uri)).resolve()
                if target in files:
                    edge(fid, files[target], 'imports_file', path,
                         source_location='L' + str(text[:match.start()].count('\n') + 1))
        for channel in set(re.findall(r'''["']((?:studystream|tangerine)[/.][A-Za-z0-9_./-]+)["']''', text)):
            if '/' not in channel and 'MethodChannel' not in text[max(0, text.find(channel)-180):text.find(channel)+180]:
                continue
            cid = node('platform_channel_' + identity(channel), channel, path, 'concept', extraction_mode='channel_literal')
            edge(fid, cid, 'uses_channel', path)
            channels[channel].append(path.relative_to(ROOT).as_posix())
        if path.name == 'app.dart':
            for route in re.findall(r'''\bpath\s*:\s*['"]([^'"]+)['"]''', text):
                rid = node('app_route_' + identity(route or 'home'), 'Route ' + route, path)
                edge(fid, rid, 'registers_route', path)

    fixture_path = ROOT / 'test/fixtures/lesson.wav'
    if fixture_path.exists():
        with wave.open(str(fixture_path)) as wav:
            details = {'seconds': wav.getnframes() / wav.getframerate(), 'channels': wav.getnchannels(),
                       'sample_rate': wav.getframerate(), 'spoken_transcript': 'Not applicable: documented synthetic PCM tone'}
        for record in records:
            if record['path'] == 'test/fixtures/lesson.wav': record['media'] = details
    for rel in ('test/fixtures/lesson.wav', 'test/fixtures/motion.mp4'):
        path = ROOT / rel
        if path in files:
            fixture = node('synthetic_playback_fixture', 'Synthetic playback fixtures', ROOT / 'test/fixtures/README.md')
            edge(fixture, files[path], 'documents_fixture', ROOT / 'test/fixtures/README.md')
    bundle_counts = Counter(row['path'].split('/')[1] for row in evidence)
    metadata = {'generated_at': datetime.now(timezone.utc).isoformat(),
                'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'files': records, 'source_files': len(records), 'evidence_files': len(evidence),
                'evidence_bundles': dict(bundle_counts), 'schema_tables': sorted(schemas),
                'platform_channels': dict(channels)}
    (OUT / 'FILE_INVENTORY.json').write_text(json.dumps(metadata, indent=2))
    (OUT / 'EVIDENCE_INVENTORY.json').write_text(json.dumps({'mode': 'inventory_only', 'files': evidence}, indent=2))
    return {'nodes': nodes, 'edges': edges, 'hyperedges': []}, metadata


def main():
    from graphify.detect import detect, save_manifest
    from graphify.watch import _read_build_excludes
    from graphify.extract import extract
    from graphify.build import build_from_json
    from graphify.cluster import cluster, score_all, label_communities_by_hub
    from graphify.analyze import god_nodes, surprising_connections, suggest_questions
    from graphify.report import generate
    from graphify.export import to_json, to_html, backup_if_protected
    from graphify.diagnostics import diagnose_extraction, format_diagnostic_report

    OUT.mkdir(exist_ok=True)
    detection = detect(ROOT, extra_excludes=_read_build_excludes(OUT), gitignore=True)
    (OUT / '.graphify_detect.json').write_text(json.dumps(detection, indent=2))
    # Graphify also extracts Markdown headings structurally. Keep these alongside
    # the curated document semantics so a new review/report is not dropped when
    # switching from the incremental CLI to this project-specific mapper.
    ast = extract([Path(p) for p in detection['files']['code']], cache_root=ROOT, root=ROOT, parallel=False)
    documents = [Path(p) for p in detection['files'].get('document', [])
                 if Path(p).suffix.lower() in {'.md', '.markdown'}]
    document_ast = extract(documents, cache_root=ROOT, root=ROOT, parallel=False)
    # The inventory below already owns document-file nodes. Adding a second
    # AST file node makes Graphify fold curated document aliases into it, which
    # its semantic-preservation guard correctly rejects. Retain headings only,
    # attaching them to the same inventory file IDs used by the existing map.
    for heading in document_ast['nodes']:
        if heading.get('node_kind') != 'heading':
            continue
        ast['nodes'].append(heading)
        path = ROOT / heading['source_file']
        ast['edges'].append({
            'source': file_id(path), 'target': heading['id'],
            'relation': 'contains_heading', 'confidence': 'EXTRACTED',
            'confidence_score': 1.0, 'source_file': heading['source_file'],
            'source_location': heading.get('source_location'),
            'weight': 1.0, '_origin': 'ast',
        })
    (OUT / '.graphify_ast.json').write_text(json.dumps(ast, indent=2))
    semantic_path = OUT / 'semantic-extraction.json'
    if not semantic_path.exists(): raise SystemExit('semantic-extraction.json is required; run the Graphify skill to extract documents and images first.')
    semantic = json.loads(semantic_path.read_text())
    supplement, metadata = inventory_and_adapters(ast)
    merged = {'nodes': ast['nodes'] + semantic['nodes'] + supplement['nodes'],
              'edges': ast['edges'] + semantic['edges'] + supplement['edges'],
              'hyperedges': semantic.get('hyperedges', []), 'input_tokens': 0, 'output_tokens': 0}
    invalid_edges = [e for e in merged['edges'] if not e.get('source') or not e.get('target')]
    (OUT / 'INVALID_RELATIONSHIPS.json').write_text(json.dumps(invalid_edges, indent=2))
    merged['edges'] = [e for e in merged['edges'] if e.get('source') and e.get('target')]
    merged['nodes'] = [n for n in merged['nodes'] if n.get('id')]
    # Reconcile duplicate IDs with real source locations preferred over inventory.
    deduped = {}
    for n in merged['nodes']:
        old = deduped.get(n['id'])
        if old is None: deduped[n['id']] = n
        elif n.get('source_file') and not old.get('source_file'): deduped[n['id']] = {**old, **n}
    merged['nodes'] = list(deduped.values())
    ids = set(deduped)
    dangling = {e[k] for e in merged['edges'] for k in ('source', 'target') if e[k] not in ids}
    for nid in sorted(dangling):
        merged['nodes'].append({'id': nid, 'label': nid.replace('_', ' '), 'file_type': 'concept',
                               'source_file': None, 'source_location': None, '_origin': 'semantic',
                               'unresolved_reference': True})
    (OUT / '.graphify_extract.json').write_text(json.dumps(merged, indent=2))
    (OUT / 'RAW_RELATIONSHIPS.json').write_text(json.dumps(merged['edges'], indent=2))
    graph = build_from_json(merged, root=ROOT, directed=True, dedup=False)
    communities = cluster(graph)
    cohesion = score_all(graph, communities)
    labels = label_communities_by_hub(graph, communities)
    names_path = OUT / 'community-labels.json'
    names = json.loads(names_path.read_text()) if names_path.exists() else {}
    seen_labels = Counter()
    for cid, members in communities.items():
        present = sorted((n for n in members if n in graph), key=lambda n: (-graph.degree(n), n))
        chosen = None
        for nid in present:
            source = str(graph.nodes[nid].get('source_file') or '')
            if Path(source).name in names:
                chosen = names[Path(source).name]
                break
        if chosen is None:
            label = str(labels[cid])
            if label.startswith('package:'): chosen = 'External Flutter Dependencies'
            elif label.startswith('dart:'): chosen = 'Dart Runtime Dependencies'
            else:
                label = re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', label)
                label = re.sub(r'[^a-zA-Z0-9 ]+', ' ', label).strip()
                chosen = ' '.join(label.split()[:5]).title() or 'External Runtime Types'
        seen_labels[chosen] += 1
        labels[cid] = chosen if seen_labels[chosen] == 1 else f'{chosen} {seen_labels[chosen]}'
    gods = god_nodes(graph)
    surprises = surprising_connections(graph, communities)
    questions = suggest_questions(graph, communities, labels)
    commit = metadata['commit']
    verified_empty_cleanup = False
    if (OUT / 'graph.json').exists():
        previous = json.loads((OUT / 'graph.json').read_text())
        previous_ids = {n['id'] for n in previous['nodes']}
        removed = previous_ids - set(graph)
        if removed == {''} and graph.number_of_nodes() >= len(previous_ids) - 1:
            backup_if_protected(OUT)
            verified_empty_cleanup = True
    if not to_json(graph, communities, str(OUT / 'graph.json'), community_labels=labels,
                   built_at_commit=commit, original_links=merged['edges'], force=verified_empty_cleanup):
        raise SystemExit('Graphify refused to replace an existing larger graph; previous outputs are preserved.')
    report = generate(graph, communities, cohesion, labels, gods, surprises, detection,
                      {'input': 0, 'output': 0}, str(ROOT), suggested_questions=questions, built_at_commit=commit)
    report += '\n\n## Coverage and limits\n\n'
    report += f"- Full source/configuration/asset inventory: {metadata['source_files']} files in `FILE_INVENTORY.json`.\n"
    report += f"- Local research evidence: {metadata['evidence_files']} files inventoried separately in `EVIDENCE_INVENTORY.json`; binaries and generated decompilation dumps were not re-analyzed.\n"
    report += '- Dart uses Graphify’s regex extractor; supported native languages use tree-sitter. This is a structural/semantic map, not compiler or runtime proof.\n'
    report += f'- Discarded {len(invalid_edges)} empty-endpoint records emitted by the Dart extractor; originals are retained in `INVALID_RELATIONSHIPS.json`.\n'
    report += f'- {len(dangling)} cited symbols or paths are explicit unresolved-reference nodes, not verified definitions.\n'
    report += '- Native configuration files and binary assets have file/relationship coverage; not every configuration expression is semantically interpreted.\n'
    report += '- Synthetic tone/animation fixtures contain no spoken program material; no speech model or transcription was run.\n'
    report += '- One Linux macro header has a tree-sitter parse limitation. Nine build/configuration/header files produce no structural symbols; their inventory nodes are retained.\n'
    report += '- Semantic extraction ran in this Codex session. Separate API usage was zero; host-session token counts are unavailable and the zero counters are not total session-cost estimates.\n'
    report += '- No application tests were run for this mapping task; test nodes describe definitions and dependencies, not pass/fail results.\n'
    health = diagnose_extraction(merged, directed=True, root=ROOT)
    (OUT / 'GRAPH_HEALTH.json').write_text(json.dumps(health, indent=2, default=str))
    report += '\n### Graph integrity\n\n```text\n' + format_diagnostic_report(health) + '\n```\n'
    (OUT / 'GRAPH_REPORT.md').write_text(report)
    analysis = {'communities': {str(k): v for k, v in communities.items()},
                'cohesion': {str(k): v for k, v in cohesion.items()}, 'gods': gods,
                'surprises': surprises, 'questions': questions}
    (OUT / '.graphify_analysis.json').write_text(json.dumps(analysis, indent=2))
    (OUT / '.graphify_labels.json').write_text(json.dumps(labels, indent=2))
    to_html(graph, communities, str(OUT / 'graph.html'), community_labels=labels,
            node_limit=max(5000, graph.number_of_nodes()))
    # Use a locally cached, integrity-checked visualization dependency if present.
    vendor = OUT / 'vendor/vis-network.min.js'
    if vendor.exists():
        html = (OUT / 'graph.html').read_text()
        pattern = r'<script src="https://unpkg.com/vis-network@9\.1\.6/standalone/umd/vis-network\.min\.js".*?</script>'
        html = re.sub(pattern, lambda _: '<script>\n' + vendor.read_text().replace('</script', '<\\/script') + '\n</script>', html, count=1, flags=re.S)
        (OUT / 'graph.html').write_text(html)
    corpus = detection['files']
    save_manifest(corpus, manifest_path=str(OUT / 'manifest.json'), root=ROOT,
                  scan_corpus={f for group in corpus.values() for f in group})
    print(json.dumps({'nodes': graph.number_of_nodes(), 'edges': graph.number_of_edges(),
                      'communities': len(communities), 'source_files': metadata['source_files'],
                      'evidence_files': metadata['evidence_files'], 'unresolved_references': len(dangling)}))


if __name__ == '__main__':
    main()
