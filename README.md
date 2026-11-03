# 🐍 COBRASONG

**Música, comunidade e jogos em um só lugar.**

COBRASONG é um projeto multiplataforma em Flutter para Android, iOS, Windows e Web.

## Versão atual — 0.2.0

Esta primeira base inclui:
- Interface responsiva com tema preto, roxo e verde neon.
- Navegação entre Início, Explorar, Salas, Jogos, Biblioteca e COBRA CARDS.
- Player demonstrativo com play/pause e troca de faixa.
- Faixas fictícias para testar a interface, sem áudio protegido por direitos autorais.
- Seção COBRA CARDS com coleção demonstrativa, filtro por raridade e favoritos.
- Estrutura inicial preparada para evoluir para experiências sociais e multiplayer.

## Executar localmente

É necessário ter o Flutter SDK instalado.

```bash
flutter create . --platforms=android,ios,web,windows
flutter pub get
flutter run
```

Para compilar:
- Android: `flutter build apk`
- Web: `flutter build web`
- Windows: `flutter build windows` (em Windows com o suporte habilitado)
- iOS: `flutter build ios` (em macOS com Xcode)

O GitHub Actions também gera um APK de depuração e executa análise/testes a cada atualização. O APK aparece na área **Actions → execução mais recente → Artifacts** quando a execução termina com sucesso.

## Próximas etapas

1. Persistência de playlists, favoritos e coleção de cartas.
2. Autenticação e perfis.
3. Salas sincronizadas com backend em tempo real.
4. Chat, convites e reações.
5. Mini games, XP e conquistas.
6. Integração com catálogos musicais autorizados e APIs compatíveis.

> **Importante:** a versão 0.1.0 é um protótipo de interface. As salas ainda não conectam usuários e as faixas exibidas são dados fictícios; reprodução de catálogo real depende de licenças e integrações permitidas.

## Identidade visual

Preto profundo, roxo elétrico e verde neon. O conceito mistura música, tecnologia e comunidade.
