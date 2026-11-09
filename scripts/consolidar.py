"""Consolida os 8 blocos obrigatórios em Markdown para revisão. Não gera PDF."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
names = [
    '01-concepcao.md',
    '02-requisitos.md',
    '03-arquitetura.md',
    '04-uml.md',
    '05-banco.md',
    '07-planejamento.md',
    '08-dev.md',
    '09-qualidade.md',
]
output = root / 'PROJETO_COMPLETO.md'
parts = [
    '# MentorIA Acadêmica — Documento Consolidado para Revisão Acadêmica\n\n',
    '> Documento técnico dos três integrantes. O sistema não está implementado; os scripts SQL e testes devem ser executados e validados em um PostgreSQL real. Veja orientações no `README.md`.\n\n',
]
for name in names:
    document = root / 'docs' / name
    content = document.read_text(encoding='utf-8')
    # Preserva links locais quando o texto muda de docs/ para a raiz.
    def reescrever_link(match):
        prefixo, texto, destino = match.group(1), match.group(2), match.group(3)
        if destino.startswith(('http://', 'https://', 'mailto:', '#', '/')):
            return match.group(0)
        caminho, separador, ancora = destino.partition('#')
        alvo = (document.parent / caminho).resolve()
        try:
            relativo = alvo.relative_to(root.resolve()).as_posix()
        except ValueError:
            return match.group(0)
        return f'{prefixo}[{texto}]({relativo}{separador + ancora if separador else ""})' if alvo.exists() else match.group(0)
    content = re.sub(r'(!?)\[([^\]]+)\]\(([^)]+)\)', reescrever_link, content)
    parts.append(content)
    parts.append('\n\n---\n\n')
output.write_text(''.join(parts), encoding='utf-8')
print('Arquivo consolidado:', output)
