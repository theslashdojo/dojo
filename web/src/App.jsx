import { useState, useEffect, useRef } from 'react'
import ReactMarkdown from 'react-markdown'
import { ChevronRight, ChevronDown, Search, Link as LinkIcon, Code, ArrowUpRight, BookOpen, Zap, Box, Globe, Layers, FileText, Copy, Check, ExternalLink, Terminal, Sparkles, ArrowRight, Moon, Sun } from 'lucide-react'

const DEFAULT_ECOSYSTEMS = [
  'dojo',
  'openai',
  'github',
  'aws',
  'vercel',
  'docker',
  'postgres',
  'redis',
  'slack',
  'notion',
  'twilio',
  'stripe',
  'ethereum',
  'database',
]

function sortEcosystems(items) {
  return [...new Set(items)].sort((a, b) => {
    if (a === 'dojo') return -1
    if (b === 'dojo') return 1
    return a.localeCompare(b)
  })
}

const TYPE_META = {
  ecosystem: { color: '#A78BFA', icon: Globe, label: 'eco' },
  standard:  { color: '#34D399', icon: Layers, label: 'std' },
  skill:     { color: '#60A5FA', icon: Zap, label: 'skill' },
  context:   { color: '#FBBF24', icon: BookOpen, label: 'ctx' },
  sub:       { color: '#6EE7B7', icon: Box, label: 'sub' },
}

const APP_SHELL_CLASS = 'dojo-explorer'
const THEME_STORAGE_KEY = 'dojo-explorer-theme'
const ACCENT = '#A78BFA'
const SUCCESS = '#34D399'
const APP_BG = 'var(--app-bg)'
const PANEL_BG = 'var(--panel-bg)'
const CODE_BG = 'var(--code-bg)'
const TONE_02 = 'var(--tone-02)'
const TONE_03 = 'var(--tone-03)'
const TONE_04 = 'var(--tone-04)'
const TONE_05 = 'var(--tone-05)'
const TONE_06 = 'var(--tone-06)'
const TONE_07 = 'var(--tone-07)'
const TONE_08 = 'var(--tone-08)'
const TONE_10 = 'var(--tone-10)'
const TONE_12 = 'var(--tone-12)'
const TONE_15 = 'var(--tone-15)'
const TONE_20 = 'var(--tone-20)'
const TONE_25 = 'var(--tone-25)'
const TONE_30 = 'var(--tone-30)'
const TONE_35 = 'var(--tone-35)'
const TEXT_PRIMARY = 'var(--tone-80)'

function getPreferredTheme() {
  if (typeof window === 'undefined') return 'dark'

  const savedTheme = window.localStorage?.getItem(THEME_STORAGE_KEY)
  if (savedTheme === 'light' || savedTheme === 'dark') return savedTheme

  return window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
}

function splitTargetUri(uri = '') {
  const value = String(uri || '').trim()
  const [baseUri, sectionId] = value.split('#')
  return {
    baseUri,
    sectionId: sectionId || null,
    fullUri: sectionId ? `${baseUri}#${sectionId}` : baseUri,
  }
}

function getAncestorUris(uri = '') {
  const { baseUri } = splitTargetUri(uri)
  if (!baseUri) return []
  const parts = baseUri.split('/').filter(Boolean)
  return parts.map((_, index) => parts.slice(0, index + 1).join('/'))
}

function parseWikiLink(raw = '') {
  const [targetPart, labelPart] = String(raw || '').split('|')
  const target = targetPart?.trim()
  if (!target) return null
  return {
    target,
    label: labelPart?.trim() || target,
  }
}

function extractExactWikiLink(text = '') {
  const match = String(text || '').trim().match(/^\[\[([^[\]]+)\]\]$/)
  return match ? parseWikiLink(match[1]) : null
}

function transformWikiLinks(markdown = '') {
  const source = String(markdown || '')
  let result = ''
  let index = 0
  let inInlineCode = false
  let inFence = false

  while (index < source.length) {
    if (source.startsWith('```', index)) {
      inFence = !inFence
      result += '```'
      index += 3
      continue
    }

    if (!inFence && source[index] === '`') {
      inInlineCode = !inInlineCode
      result += source[index]
      index += 1
      continue
    }

    if (!inFence && !inInlineCode && source.startsWith('[[', index)) {
      const endIndex = source.indexOf(']]', index + 2)
      if (endIndex !== -1) {
        const parsed = parseWikiLink(source.slice(index + 2, endIndex))
        if (parsed) {
          result += `[${parsed.label}](${parsed.target})`
          index = endIndex + 2
          continue
        }
      }
    }

    result += source[index]
    index += 1
  }

  return result
}

// ─── Animations keyframes injected once ───────────────
const STYLES = `
@import url('https://fonts.googleapis.com/css2?family=DM+Mono:wght@300;400;500&family=Fraunces:opsz,wght,SOFT@9..144,300..900,0..100&family=Satoshi:wght@300;400;500;700&display=swap');

.${APP_SHELL_CLASS},
.${APP_SHELL_CLASS}[data-theme="dark"] {
  color-scheme: dark;
  --app-bg: #0C0C0F;
  --panel-bg: rgba(12,12,15,0.82);
  --code-bg: rgba(0,0,0,0.25);
  --tone-02: rgba(255,255,255,0.02);
  --tone-03: rgba(255,255,255,0.03);
  --tone-04: rgba(255,255,255,0.04);
  --tone-05: rgba(255,255,255,0.05);
  --tone-06: rgba(255,255,255,0.06);
  --tone-07: rgba(255,255,255,0.07);
  --tone-08: rgba(255,255,255,0.08);
  --tone-10: rgba(255,255,255,0.10);
  --tone-12: rgba(255,255,255,0.12);
  --tone-15: rgba(255,255,255,0.15);
  --tone-20: rgba(255,255,255,0.20);
  --tone-25: rgba(255,255,255,0.25);
  --tone-30: rgba(255,255,255,0.30);
  --tone-35: rgba(255,255,255,0.35);
  --tone-80: rgba(255,255,255,0.82);
  --selection-bg: rgba(167,139,250,0.28);
  --selection-text: #fff;
}

.${APP_SHELL_CLASS}[data-theme="light"] {
  color-scheme: light;
  --app-bg: #F5F1EA;
  --panel-bg: rgba(255,255,255,0.62);
  --panel-bg-strong: rgba(255,255,255,0.78);
  --code-bg: rgba(0,0,0,0.04);
  --glass-border: rgba(15,15,15,0.08);
  --glass-highlight: rgba(255,255,255,0.7);
  --tone-02: rgba(20,15,8,0.02);
  --tone-03: rgba(20,15,8,0.03);
  --tone-04: rgba(20,15,8,0.04);
  --tone-05: rgba(20,15,8,0.05);
  --tone-06: rgba(20,15,8,0.06);
  --tone-07: rgba(20,15,8,0.07);
  --tone-08: rgba(20,15,8,0.09);
  --tone-10: rgba(20,15,8,0.11);
  --tone-12: rgba(20,15,8,0.14);
  --tone-15: rgba(20,15,8,0.18);
  --tone-20: rgba(20,15,8,0.24);
  --tone-25: rgba(20,15,8,0.30);
  --tone-30: rgba(20,15,8,0.36);
  --tone-35: rgba(20,15,8,0.42);
  --tone-80: rgba(20,12,4,0.88);
  --selection-bg: rgba(167,139,250,0.22);
  --selection-text: #1a0f04;
  --accent: #7C3AED;
  --accent-2: #2563EB;
  --success: #059669;
}

.${APP_SHELL_CLASS} {
  background: var(--app-bg);
  color: var(--tone-80);
}

.${APP_SHELL_CLASS} * {
  box-sizing: border-box;
}

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}
@keyframes slideIn {
  from { opacity: 0; transform: translateX(-8px); }
  to { opacity: 1; transform: translateX(0); }
}
@keyframes pulse-glow {
  0%, 100% { box-shadow: 0 0 8px rgba(167,139,250,0.15); }
  50% { box-shadow: 0 0 20px rgba(167,139,250,0.3); }
}
@keyframes grain {
  0%, 100% { transform: translate(0,0); }
  10% { transform: translate(-5%,-10%); }
  30% { transform: translate(3%,-15%); }
  50% { transform: translate(12%,9%); }
  70% { transform: translate(9%,4%); }
  90% { transform: translate(-1%,7%); }
}

.${APP_SHELL_CLASS} ::-webkit-scrollbar { width: 5px; }
.${APP_SHELL_CLASS} ::-webkit-scrollbar-track { background: transparent; }
.${APP_SHELL_CLASS} ::-webkit-scrollbar-thumb { background: ${TONE_06}; border-radius: 10px; }
.${APP_SHELL_CLASS} ::-webkit-scrollbar-thumb:hover { background: ${TONE_12}; }

.${APP_SHELL_CLASS} ::selection { background: var(--selection-bg); color: var(--selection-text); }
.${APP_SHELL_CLASS} input::placeholder { color: ${TEXT_PRIMARY}; opacity: 0.5; }
`

function TypeBadge({ type, size = 'sm' }) {
  const m = TYPE_META[type] || TYPE_META.skill
  const Icon = m.icon
  const isLg = size === 'lg'
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: isLg ? 6 : 4,
      padding: isLg ? '5px 12px' : '3px 8px',
      borderRadius: 6,
      background: m.color + '14',
      border: `1px solid ${m.color}30`,
      color: m.color,
      fontSize: isLg ? 11 : 10,
      fontWeight: 500,
      fontFamily: "'DM Mono', monospace",
      letterSpacing: '0.04em',
      textTransform: 'uppercase',
    }}>
      <Icon style={{ width: isLg ? 13 : 11, height: isLg ? 13 : 11 }} />
      {type}
    </span>
  )
}

function CopyButton({ text }) {
  const [copied, setCopied] = useState(false)
  const copy = () => { navigator.clipboard?.writeText(text); setCopied(true); setTimeout(() => setCopied(false), 1500) }
  return (
    <button onClick={copy} tabIndex={0} onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); copy(); } }} style={{
      display: 'flex', alignItems: 'center', gap: 5, padding: '5px 10px',
      borderRadius: 6, border: `1px solid ${TONE_08}`, background: TONE_04,
      color: copied ? SUCCESS : TEXT_PRIMARY, fontSize: 11, cursor: 'pointer',
      fontFamily: "'DM Mono', monospace", transition: 'all 0.2s ease',
      outline: 'none',
    }}
      onMouseEnter={e => { e.currentTarget.style.background = TONE_08; e.currentTarget.style.borderColor = TONE_15 }}
      onMouseLeave={e => { e.currentTarget.style.background = TONE_04; e.currentTarget.style.borderColor = TONE_08 }}
      onFocus={e => { e.currentTarget.style.background = TONE_08; e.currentTarget.style.borderColor = TONE_15 }}
      onBlur={e => { e.currentTarget.style.background = TONE_04; e.currentTarget.style.borderColor = TONE_08 }}
    >
      {copied ? <><Check style={{ width: 12, height: 12 }} /> copied</> : <><Copy style={{ width: 12, height: 12 }} /> copy</>}
    </button>
  )
}

function ThemeToggle({ theme, onToggle }) {
  const isLight = theme === 'light'
  const Icon = isLight ? Moon : Sun

  return (
    <button
      type="button"
      onClick={onToggle}
      aria-label={`Switch to ${isLight ? 'dark' : 'light'} mode`}
      title={`Switch to ${isLight ? 'dark' : 'light'} mode`}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 6,
        borderRadius: 999,
        border: `1px solid ${TONE_08}`,
        background: TONE_03,
        color: TEXT_PRIMARY,
        cursor: 'pointer',
        fontSize: 11,
        fontFamily: "'DM Mono', monospace",
        letterSpacing: '0.03em',
        transition: 'all 0.2s ease',
        outline: 'none',
        width: 32,
        height: 32,
      }}
      onMouseEnter={e => { e.currentTarget.style.background = TONE_08; e.currentTarget.style.borderColor = TONE_15 }}
      onMouseLeave={e => { e.currentTarget.style.background = TONE_03; e.currentTarget.style.borderColor = TONE_08 }}
      onFocus={e => { e.currentTarget.style.background = TONE_08; e.currentTarget.style.borderColor = TONE_15 }}
      onBlur={e => { e.currentTarget.style.background = TONE_03; e.currentTarget.style.borderColor = TONE_08 }}
    >
      <Icon style={{ width: 13, height: 13, color: ACCENT }} />
      {isLight ? '' : ''}
    </button>
  )
}

function MarkdownBlock({ children, accentColor = ACCENT, dense = false, onNavigate }) {
  const source = transformWikiLinks(children)

  return (
    <ReactMarkdown
      components={{
        h1: ({ node, ...props }) => (
          <h1
            style={{
              margin: dense ? '0 0 10px' : '0 0 12px',
              color: TEXT_PRIMARY,
              fontFamily: "'Fraunces', serif",
              fontSize: dense ? 24 : 30,
              fontWeight: 300,
              lineHeight: 1.15,
              letterSpacing: '-0.02em',
            }}
            {...props}
          />
        ),
        h2: ({ node, ...props }) => (
          <h2
            style={{
              margin: dense ? '18px 0 10px' : '22px 0 12px',
              color: TEXT_PRIMARY,
              fontFamily: "'Fraunces', serif",
              fontSize: dense ? 20 : 24,
              fontWeight: 300,
              lineHeight: 1.2,
            }}
            {...props}
          />
        ),
        h3: ({ node, ...props }) => (
          <h3
            style={{
              margin: '18px 0 10px',
              color: TEXT_PRIMARY,
              fontFamily: "'Satoshi', sans-serif",
              fontSize: dense ? 16 : 18,
              fontWeight: 500,
              lineHeight: 1.3,
            }}
            {...props}
          />
        ),
        p: ({ node, ...props }) => (
          <p
            style={{
              margin: '0 0 14px',
              color: TEXT_PRIMARY,
              fontFamily: "'Satoshi', sans-serif",
              fontSize: dense ? 14 : 15,
              fontWeight: 300,
              lineHeight: dense ? 1.75 : 1.8,
            }}
            {...props}
          />
        ),
        ul: ({ node, ...props }) => (
          <ul
            style={{
              margin: '0 0 14px 18px',
              padding: 0,
              color: TEXT_PRIMARY,
              fontFamily: "'Satoshi', sans-serif",
            }}
            {...props}
          />
        ),
        ol: ({ node, ...props }) => (
          <ol
            style={{
              margin: '0 0 14px 18px',
              padding: 0,
              color: TEXT_PRIMARY,
              fontFamily: "'Satoshi', sans-serif",
            }}
            {...props}
          />
        ),
        li: ({ node, ...props }) => (
          <li
            style={{
              marginBottom: 6,
              color: TEXT_PRIMARY,
              fontSize: dense ? 14 : 15,
              fontWeight: 300,
              lineHeight: 1.75,
            }}
            {...props}
          />
        ),
        strong: ({ node, ...props }) => <strong style={{ color: TEXT_PRIMARY, fontWeight: 600 }} {...props} />,
        em: ({ node, ...props }) => <em style={{ color: TEXT_PRIMARY }} {...props} />,
        a: ({ node, ...props }) => {
          const href = props.href || ''
          const isInternal = href && !href.startsWith('http') && !href.startsWith('/') && !href.startsWith('#')
          return (
            <a
              href={href}
              style={{
                color: accentColor,
                textDecoration: 'none',
                borderBottom: isInternal ? `1px solid ${accentColor}40` : 'none',
              }}
              onClick={e => {
                if (isInternal && onNavigate) {
                  e.preventDefault()
                  onNavigate(href)
                }
              }}
              {...props}
            />
          )
        },
        blockquote: ({ node, ...props }) => (
          <blockquote
            style={{
              margin: '16px 0',
              padding: '2px 0 2px 16px',
              borderLeft: `2px solid ${accentColor}70`,
              color: TEXT_PRIMARY,
            }}
            {...props}
          />
        ),
        code: ({ inline, node, children: codeChildren, ...props }) => {
          const codeText = Array.isArray(codeChildren) ? codeChildren.join('') : String(codeChildren || '')
          const wikiLink = inline ? extractExactWikiLink(codeText) : null

          if (inline && wikiLink && onNavigate) {
            return (
              <a
                href={wikiLink.target}
                style={{ textDecoration: 'none' }}
                onClick={e => {
                  e.preventDefault()
                  onNavigate(wikiLink.target)
                }}
              >
                <code
                  style={{
                    padding: '',
                    borderRadius: 6,
                    background: accentColor + '14',
                    color: accentColor,
                    border: `1px solid ${accentColor}30`,
                    fontFamily: "'DM Mono', monospace",
                    fontSize: '0.92em',
                    cursor: 'pointer',
                  }}
                  {...props}
                >
                  {codeText}
                </code>
              </a>
            )
          }

          return inline ? (
            <code
              style={{
                padding: '0.12em 0.38em',
                borderRadius: 6,
                background: TONE_06,
                color: TEXT_PRIMARY,
                fontFamily: "'DM Mono', monospace",
                fontSize: '0.92em',
              }}
              {...props}
            >
              {codeChildren}
            </code>
          ) : (
            <code style={{ color: TEXT_PRIMARY, fontFamily: "'DM Mono', monospace" }} {...props}>
              {codeChildren}
            </code>
          )
        },
        pre: ({ node, ...props }) => (
          <pre
            style={{
              margin: '16px 0',
              padding: '16px 18px',
              borderRadius: 12,
              border: `1px solid ${TONE_06}`,
              background: CODE_BG,
              overflowX: 'auto',
            }}
            {...props}
          />
        ),
      }}
    >
      {source || ''}
    </ReactMarkdown>
  )
}

// ─── Tree Node ────────────────────────────────────────

function TreeNode({ node, depth, expandedNodes, toggleNode, selectedSkill, handleSelect, index = 0 }) {
  if (!node || node.error || !node.uri) return null
  const hasChildren = Array.isArray(node.skills) && node.skills.length > 0
  const isExpanded = expandedNodes.has(node.uri)
  const isSelected = selectedSkill?.uri === node.uri
  const m = TYPE_META[node.type] || TYPE_META.skill
  const name = node.name || node.uri.split('/').pop()

  return (
    <div style={{ animation: `slideIn 0.25s ease ${index * 0.03}s both` }}>
      <div
        tabIndex={0}
        onClick={() => handleSelect(node)}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            handleSelect(node)
          }
          if (e.key === 'ArrowRight' && hasChildren && !isExpanded) {
            e.preventDefault()
            toggleNode(node.uri, e)
          }
          if (e.key === 'ArrowLeft' && hasChildren && isExpanded) {
            e.preventDefault()
            toggleNode(node.uri, e)
          }
        }}
        style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: `6px 12px 6px ${14 + depth * 18}px`,
          cursor: 'pointer', borderRadius: 8, position: 'relative',
          background: isSelected ? m.color + '18' : 'transparent',
          transition: 'all 0.15s ease',
          marginBottom: 1,
          outline: 'none',
        }}
        onMouseEnter={e => { if (!isSelected) e.currentTarget.style.background = TONE_04 }}
        onMouseLeave={e => { e.currentTarget.style.background = isSelected ? m.color + '18' : 'transparent' }}
        onFocus={e => { if (!isSelected) e.currentTarget.style.background = TONE_08 }}
        onBlur={e => { e.currentTarget.style.background = isSelected ? m.color + '18' : 'transparent' }}
      >
        {isSelected && (
          <div style={{
            position: 'absolute', left: 0, top: 4, bottom: 4, width: 3,
            borderRadius: 0, background: `linear-gradient(180deg, ${m.color}, ${m.color}60)`,
          }} />
        )}

        <span
          tabIndex={hasChildren ? 0 : -1}
          onClick={e => { if (hasChildren) { e.stopPropagation(); toggleNode(node.uri, e) } }}
          onKeyDown={(e) => {
            if (hasChildren && (e.key === 'Enter' || e.key === ' ')) {
              e.preventDefault()
              e.stopPropagation()
              toggleNode(node.uri, e)
            }
          }}
          style={{
            width: 18, height: 18, display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0, cursor: hasChildren ? 'pointer' : 'default',
            borderRadius: 4,
            transition: 'background 0.15s',
            outline: 'none',
          }}
          onMouseEnter={e => { if (hasChildren) e.currentTarget.style.background = TONE_08 }}
          onMouseLeave={e => { e.currentTarget.style.background = 'transparent' }}
          onFocus={e => { if (hasChildren) e.currentTarget.style.background = TONE_12 }}
          onBlur={e => { e.currentTarget.style.background = 'transparent' }}
        >
          {hasChildren ? (isExpanded
            ? <ChevronDown style={{ width: 13, height: 13, color: TONE_35 }} />
            : <ChevronRight style={{ width: 13, height: 13, color: TONE_25 }} />
          ) : <span style={{ width: 4, height: 4, borderRadius: '50%', background: m.color, opacity: 0.5 }} />}
        </span>

        <span style={{
          fontSize: 13, fontWeight: isSelected ? 500 : 400,
          color: TEXT_PRIMARY,
          fontFamily: depth === 0 ? "'Satoshi', sans-serif" : "'DM Mono', monospace",
          letterSpacing: depth === 0 ? '0.01em' : '-0.01em',
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
          transition: 'color 0.15s',
        }}>{name}</span>

        {node.skills?.length > 0 && (
          <span style={{
            marginLeft: 'auto', fontSize: 9, padding: '1px 5px', borderRadius: 4,
            background: TYPE_META.skill.color + '18', color: TYPE_META.skill.color,
            fontFamily: "'DM Mono', monospace", fontWeight: 500, flexShrink: 0,
          }}>{node.skills.length}</span>
        )}
      </div>

      {hasChildren && isExpanded && (
        <div style={{ position: 'relative' }}>
          <div style={{
            position: 'absolute', left: 22 + depth * 18, top: 0, bottom: 8,
            width: 1, background: TONE_06,
          }} />
          {node.skills.map((child, i) => (
            <TreeNode key={child.uri || Math.random()} node={child} depth={depth + 1}
              expandedNodes={expandedNodes} toggleNode={toggleNode}
              selectedSkill={selectedSkill} handleSelect={handleSelect} index={i} />
          ))}
        </div>
      )}
    </div>
  )
}

// ─── Detail View ──────────────────────────────────────

function DetailView({ skill, backlinks, onNavigate, focusedSectionId }) {
  const [collapsedSections, setCollapsedSections] = useState(new Set())
  const sectionRefs = useRef(new Map())
  useEffect(() => setCollapsedSections(new Set()), [skill?.uri])
  useEffect(() => {
    if (focusedSectionId) {
      setCollapsedSections(prev => {
        const next = new Set(prev)
        next.delete(focusedSectionId)
        return next
      })
    }
  }, [focusedSectionId])
  useEffect(() => {
    if (!focusedSectionId) return
    const sectionElement = sectionRefs.current.get(focusedSectionId)
    if (!sectionElement) return
    const frame = requestAnimationFrame(() => {
      sectionElement.scrollIntoView({ behavior: 'smooth', block: 'start' })
    })
    return () => cancelAnimationFrame(frame)
  }, [skill?.uri, focusedSectionId])

  if (!skill) return (
    <div style={{
      height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center',
      flexDirection: 'column', gap: 16,
    }}>
      <div style={{
        width: 64, height: 64, borderRadius: 20, display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: TONE_03, border: `1px solid ${TONE_06}`,
      }}>
        <Sparkles style={{ width: 28, height: 28, color: TONE_12 }} />
      </div>
      <span style={{ fontSize: 15, color: TEXT_PRIMARY, fontWeight: 300, fontFamily: "'Satoshi', sans-serif" }}>
        Select a node to explore
      </span>
    </div>
  )

  const m = TYPE_META[skill.type] || TYPE_META.skill
  const mono = "'DM Mono', monospace"
  const parts = (skill.uri || '').split('/')
  const isCtx = skill.type !== ''
  const selectedUri = focusedSectionId ? `${skill.uri}#${focusedSectionId}` : skill.uri

  const toggleSection = id => {
    setCollapsedSections(prev => { const next = new Set(prev); next.has(id) ? next.delete(id) : next.add(id); return next })
  }

  const Section = ({ label, icon: Icon, children, delay = 0 }) => (
    <div style={{ marginBottom: 32, animation: `fadeUp 0.4s ease ${delay}s both` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
        {Icon && <Icon style={{ width: 13, height: 13, color: TONE_25 }} />}
        <span style={{
          fontSize: 10, fontWeight: 500, color: TONE_30,
          letterSpacing: '0.14em', fontFamily: mono, textTransform: 'uppercase',
        }}>{label}</span>
        <div style={{ flex: 1, height: 1, background: TONE_05, marginLeft: 8 }} />
      </div>
      {children}
    </div>
  )

  return (
    <div style={{ padding: '36px 44px 60px', maxWidth: '100%', margin: '0 auto' }}>
      {/* Breadcrumb */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 2, marginBottom: 28,
        flexWrap: 'wrap', animation: 'fadeIn 0.3s ease both',
      }}>
          {parts.map((part, i) => (
            <span key={i} style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
              {i > 0 && <ChevronRight style={{ width: 11, height: 11, color: TONE_15, margin: '0 2px' }} />}
              <span
                tabIndex={i < parts.length - 1 ? 0 : -1}
                onClick={() => i < parts.length - 1 && onNavigate({ uri: parts.slice(0, i + 1).join('/') })}
                onKeyDown={e => {
                  if (i < parts.length - 1 && (e.key === 'Enter' || e.key === ' ')) {
                    e.preventDefault();
                    onNavigate({ uri: parts.slice(0, i + 1).join('/') });
                  }
                }}
                style={{
                  fontSize: 12, fontFamily: mono,
                  color: i === parts.length - 1 ? m.color : TONE_30,
                  fontWeight: i === parts.length - 1 ? 500 : 400,
                  cursor: i < parts.length - 1 ? 'pointer' : 'default',
                  padding: '2px 6px', borderRadius: 4,
                  transition: 'all 0.15s',
                  outline: 'none',
                }}
                onMouseEnter={e => { if (i < parts.length - 1) e.currentTarget.style.background = TONE_06 }}
                onMouseLeave={e => { e.currentTarget.style.background = 'transparent' }}
                onFocus={e => { if (i < parts.length - 1) e.currentTarget.style.background = TONE_10 }}
                onBlur={e => { e.currentTarget.style.background = 'transparent' }}
              >{part}</span>
            </span>
          ))}
          {focusedSectionId && (
            <span style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
              <ChevronRight style={{ width: 11, height: 11, color: TONE_15, margin: '0 2px' }} />
              <span style={{
                fontSize: 12, fontFamily: mono,
                color: m.color, fontWeight: 500,
                padding: '2px 6px', borderRadius: 4,
                background: m.color + '12',
              }}>#{focusedSectionId}</span>
            </span>
          )}
      </div>

      {/* Title */}
      <div style={{ animation: 'fadeUp 0.4s ease 0.05s both' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 16, marginBottom: 10 }}>
          <h1 style={{
            fontFamily: "'Fraunces', serif", fontSize: 40, fontWeight: 300, fontStyle: 'normal',
            color: TEXT_PRIMARY, margin: 0, lineHeight: 1.1, letterSpacing: '-0.025em', flex: 1,
          }}>
            {skill.name || parts[parts.length - 1]}
          </h1>
          <span style={{
            fontSize: 11, color: TONE_30, fontFamily: mono,
            padding: '5px 10px', background: TONE_04,
            borderRadius: 6, border: `1px solid ${TONE_06}`,
            flexShrink: 0, marginTop: 8,
          }}>
            v{skill.version || '0.0.0'}
          </span>
        </div>

        {/* Type + tags */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 20 }}>
          <TypeBadge type={skill.type} size="lg" />
          {skill.content_type && (
            <span style={{
              fontSize: 11, padding: '4px 10px', borderRadius: 6,
              background: TONE_04, color: TONE_35,
              border: `1px solid ${TONE_06}`, fontFamily: mono,
            }}>{skill.content_type}</span>
          )}
        </div>

        {focusedSectionId && (
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 10, marginBottom: 22,
            padding: '10px 14px', borderRadius: 10, background: m.color + '12',
            border: `1px solid ${m.color}30`,
          }}>
            <span style={{
              fontSize: 10, fontWeight: 500, color: m.color, letterSpacing: '0.12em',
              fontFamily: mono, textTransform: 'uppercase',
            }}>Focused section</span>
            <span style={{ fontSize: 14, color: TEXT_PRIMARY, fontFamily: "'Satoshi', sans-serif" }}>
              {skill.sections?.find(section => section.id === focusedSectionId)?.title || focusedSectionId}
            </span>
            <span style={{
              fontSize: 10, color: TONE_30, fontFamily: mono,
              padding: '2px 6px', borderRadius: 4, background: TONE_04,
            }}>
              {focusedSectionId}
            </span>
          </div>
        )}
      </div>

      {/* Context quote */}
      {skill.context && (
        <div style={{
          animation: 'fadeUp 0.4s ease 0.1s both',
          position: 'relative', padding: '18px 22px', marginBottom: 32,
          background: `linear-gradient(135deg, ${m.color}0A, transparent)`,
          overflow: 'hidden',
        }}>
          <div style={{
            position: 'absolute', left: 0, top: 0, bottom: 0, width: 3,
            background: `linear-gradient(180deg, ${m.color}, ${m.color}30)`,
          }} />
          <p style={{
            fontSize: 16, color: TEXT_PRIMARY, lineHeight: 1.65, fontWeight: 300,
            margin: 0, fontFamily: "'Satoshi', sans-serif",
          }}>{skill.context}</p>
        </div>
      )}

      {/* Tags */}
      {skill.tags?.length > 0 && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 28, animation: 'fadeUp 0.4s ease 0.12s both' }}>
          {skill.tags.map(tag => (
            <span key={tag} style={{
              fontSize: 11, padding: '4px 11px', borderRadius: 20,
              background: TONE_04, color: TEXT_PRIMARY,
              border: `1px solid ${TONE_07}`,
              fontFamily: "'Satoshi', sans-serif", fontWeight: 400,
            }}>
              {tag}
            </span>
          ))}
        </div>
      )}


      {/* Info */}
      {skill.info && (
        <Section label="Overview" icon={BookOpen} delay={0.15}>
          <MarkdownBlock accentColor={m.color} dense onNavigate={onNavigate}>{skill.info}</MarkdownBlock>
        </Section>
      )}

      {/* Body */}
      {skill.body && (
        <Section label="Body" icon={FileText} delay={0.2}>
          <MarkdownBlock accentColor={m.color} onNavigate={onNavigate}>{skill.body}</MarkdownBlock>
          <div style={{ marginTop: 18 }}>
            {skill.sections?.map((s, i) => {
              const isOpen = !collapsedSections.has(s.id)
              const isFocused = focusedSectionId === s.id
              return (
                  <div
                    key={s.id}
                    ref={element => {
                      if (element) sectionRefs.current.set(s.id, element)
                      else sectionRefs.current.delete(s.id)
                    }}
                    style={{
                      marginBottom: 10,
                      borderRadius: 12,
                      border: isFocused ? `1px solid ${m.color}35` : '1px solid transparent',
                      background: isFocused ? m.color + '0D' : 'transparent',
                      scrollMarginTop: 24,
                    }}
                  >
                    {i > 0 && <div  />}
                    <div
                      tabIndex={0}
                      onClick={() => toggleSection(s.id)}
                      onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleSection(s.id); } }}
                      style={{
                        background: isFocused ? m.color + '14' : (isOpen ? TONE_03 : 'transparent'),
                        display: 'flex', alignItems: 'center', gap: 10, padding: '13px 18px',
                        cursor: 'pointer',
                        transition: 'background 0.15s',
                        outline: 'none',
                      }}
                      onMouseEnter={e => {
                        e.currentTarget.style.background = isFocused ? m.color + '18' : TONE_04
                      }}
                      onMouseLeave={e => {
                        e.currentTarget.style.background = isFocused ? m.color + '14' : (isOpen ? TONE_03 : 'transparent')
                      }}
                      onFocus={e => {
                        e.currentTarget.style.background = isFocused ? m.color + '1C' : TONE_06
                      }}
                      onBlur={e => {
                        e.currentTarget.style.background = isFocused ? m.color + '14' : (isOpen ? TONE_03 : 'transparent')
                      }}
                    >
                    <span style={{ fontSize: 14, color: isFocused ? m.color : TYPE_META.context.color, fontFamily: mono, fontWeight: 500 }}>#</span>
                    <span style={{ fontSize: 14, color: TEXT_PRIMARY, fontWeight: isFocused ? 500 : 400, flex: 1, fontFamily: "'Satoshi', sans-serif" }}>{s.title}</span>
                    <span style={{ fontSize: 10, color: TONE_20, fontFamily: mono }}>{s.id}</span>
                    <ChevronDown style={{
                      width: 14, height: 14, color: isFocused ? m.color : TONE_25,
                      transform: isOpen ? 'rotate(0)' : 'rotate(-90deg)',
                      transition: 'transform 0.25s cubic-bezier(0.4,0,0.2,1)',
                    }} />
                  </div>
                  {isOpen && s.body && (
                    <div style={{
                      margin: '4px 0 10px',
                      padding: isFocused ? '0 14px 6px' : 0,
                      animation: 'fadeIn 0.2s ease both',
                    }}>
                      <MarkdownBlock accentColor={m.color} dense onNavigate={onNavigate}>{s.body}</MarkdownBlock>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        
        </Section>
      )}


      {/* Install */}
      {skill.uri && (
        <Section label={isCtx ? 'Learn' : 'Install'} icon={Terminal} delay={0.25}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
            padding: '14px 18px', borderRadius: 12,
            background: TONE_02, border: `1px solid ${TONE_06}`,
          }}>
            <code style={{ fontSize: 13, fontFamily: mono, color: TEXT_PRIMARY }}>
              <span style={{ color: m.color }}>$</span>
              <span style={{ color: TONE_25, margin: '0 8px' }}>dojo</span>
              <span style={{ color: SUCCESS }}>{isCtx ? 'learn' : 'install'}</span>
              <span style={{ color: TEXT_PRIMARY, marginLeft: 8 }}>{isCtx ? selectedUri : skill.uri}</span>
            </code>
            <CopyButton text={`dojo ${isCtx ? 'learn' : 'install'} ${isCtx ? selectedUri : skill.uri}`} />
          </div>
        </Section>
      )}

      {/* Scripts */}
      {skill.scripts?.length > 0 && (
        <Section label="Scripts" icon={Code} delay={0.28}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {skill.scripts.map(script => (
              <div key={script.id || script} style={{
                borderRadius: 12, border: `1px solid ${TONE_06}`, overflow: 'hidden',
              }}>
                <div style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                  padding: '12px 18px', background: TONE_03,
                  borderBottom: (script.inline || script.description) ? `1px solid ${TONE_05}` : 'none',
                }}>
                  <span style={{ fontFamily: mono, fontSize: 13, fontWeight: 500, color: TYPE_META.skill.color }}>
                    {script.id || script}
                  </span>
                  {script.lang && (
                    <span style={{
                      fontSize: 10, fontFamily: mono, color: TONE_30,
                      padding: '2px 8px', background: TONE_04, borderRadius: 5,
                      border: `1px solid ${TONE_06}`,
                    }}>{script.lang}</span>
                  )}
                </div>
                {script.description && (
                  <div style={{ padding: '12px 18px', fontSize: 13, color: TEXT_PRIMARY, fontWeight: 300 }}>
                    {script.description}
                  </div>
                )}
                {script.inline && (
                  <pre style={{
                    margin: 0, padding: '16px 20px', fontSize: 12, fontFamily: mono,
                    color: TEXT_PRIMARY, background: CODE_BG,
                    overflowX: 'auto', lineHeight: 1.7, maxHeight: 260, overflowY: 'auto',
                  }}><code>{script.inline}</code></pre>
                )}
              </div>
            ))}
          </div>
        </Section>
      )}

      {/* Dependencies */}
      {skill.depends?.length > 0 && (
        <Section label="Dependencies" icon={LinkIcon} delay={0.3}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {skill.depends.map(dep => (
                <div key={dep.uri}
                  tabIndex={0}
                  onClick={() => onNavigate({ uri: dep.uri })}
                  onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onNavigate({ uri: dep.uri }); } }}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 10, padding: '10px 16px',
                    borderRadius: 10, cursor: 'pointer', border: `1px solid ${TONE_06}`,
                    transition: 'all 0.15s ease', background: 'transparent',
                    outline: 'none',
                  }}
                  onMouseEnter={e => {
                    e.currentTarget.style.background = TONE_03
                    e.currentTarget.style.borderColor = TYPE_META.skill.color + '40'
                    e.currentTarget.style.transform = 'translateX(4px)'
                  }}
                  onMouseLeave={e => {
                    e.currentTarget.style.background = 'transparent'
                    e.currentTarget.style.borderColor = TONE_06
                    e.currentTarget.style.transform = 'translateX(0)'
                  }}
                  onFocus={e => {
                    e.currentTarget.style.background = TONE_06
                    e.currentTarget.style.borderColor = TYPE_META.skill.color + '60'
                    e.currentTarget.style.transform = 'translateX(4px)'
                  }}
                  onBlur={e => {
                    e.currentTarget.style.background = 'transparent'
                    e.currentTarget.style.borderColor = TONE_06
                    e.currentTarget.style.transform = 'translateX(0)'
                  }}
                >
                <ArrowRight style={{ width: 12, height: 12, color: TYPE_META.skill.color, opacity: 0.6 }} />
                <span style={{ fontFamily: mono, fontSize: 13, color: TYPE_META.skill.color }}>{dep.uri}</span>
                {dep.optional && (
                  <span style={{
                    fontSize: 9, padding: '2px 6px', borderRadius: 4,
                    border: `1px solid ${TONE_08}`, color: TONE_30,
                    fontFamily: mono, textTransform: 'uppercase', letterSpacing: '0.05em',
                  }}>opt</span>
                )}
                {dep.reason && (
                  <span style={{ fontSize: 12, color: TONE_25, fontWeight: 300, marginLeft: 'auto' }}>
                    {dep.reason}
                  </span>
                )}
              </div>
            ))}
          </div>
        </Section>
      )}

      {/* Schema */}
      {skill.schema && (skill.schema.input || skill.schema.output) && (
        <Section label="Schema" icon={Layers} delay={0.32}>
          <div style={{ display: 'flex', gap: 14 }}>
            {['input', 'output'].filter(k => skill.schema[k]).map(k => (
              <div key={k} style={{
                flex: 1, padding: 16, borderRadius: 12, background: TONE_02,
                border: `1px solid ${TONE_06}`,
              }}>
                <div style={{
                  fontSize: 10, fontFamily: mono, color: k === 'input' ? ACCENT : SUCCESS,
                  marginBottom: 10, fontWeight: 500, letterSpacing: '0.1em', textTransform: 'uppercase',
                }}>{k}</div>
                <pre style={{
                  margin: 0, fontSize: 11, fontFamily: mono, color: TEXT_PRIMARY,
                  whiteSpace: 'pre-wrap', lineHeight: 1.65,
                }}>
                  {JSON.stringify(skill.schema[k].properties || skill.schema[k], null, 2)}
                </pre>
              </div>
            ))}
          </div>
        </Section>
      )}
    </div>
  )
}

// ─── Connections Panel ────────────────────────────────

function ConnectionsPanel({ skill, backlinks, onNavigate }) {
  if (!skill) return (
    <div style={{ padding: 24, color: TEXT_PRIMARY, fontSize: 12, textAlign: 'center', fontWeight: 300, marginTop: 48 }}>
      No connections
    </div>
  )

  const ConnItem = ({ uri, label, color, onClick }) => (
    <div tabIndex={0} onClick={onClick} onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onClick(); } }} style={{
      display: 'flex', alignItems: 'center', gap: 8, padding: '7px 10px', borderRadius: 7,
      cursor: 'pointer', transition: 'all 0.15s', fontSize: 11, outline: 'none',
    }}
      onMouseEnter={e => { e.currentTarget.style.background = TONE_04; e.currentTarget.style.transform = 'translateX(2px)' }}
      onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.transform = 'translateX(0)' }}
      onFocus={e => { e.currentTarget.style.background = TONE_06; e.currentTarget.style.transform = 'translateX(2px)' }}
      onBlur={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.transform = 'translateX(0)' }}
    >
      <span style={{ width: 5, height: 5, borderRadius: '50%', background: color, flexShrink: 0, boxShadow: `0 0 6px ${color}40` }} />
      <span style={{
        fontFamily: "'DM Mono', monospace", color: TEXT_PRIMARY,
        overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1,
      }}>{uri}</span>
      {label && (
        <span style={{
          fontSize: 9, color: TONE_20, fontFamily: "'DM Mono', monospace",
          flexShrink: 0, padding: '1px 5px', background: TONE_04, borderRadius: 3,
        }}>{label}</span>
      )}
    </div>
  )

  const Group = ({ title, icon: Icon, children, empty }) => (
    <div style={{ marginBottom: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '0 10px', marginBottom: 8 }}>
        <Icon style={{ width: 11, height: 11, color: TONE_20 }} />
        <span style={{
          fontSize: 9, fontWeight: 500, color: TONE_25,
          letterSpacing: '0.12em', fontFamily: "'DM Mono', monospace", textTransform: 'uppercase',
        }}>{title}</span>
      </div>
      {children || (
        <div style={{ padding: '6px 10px', fontSize: 11, color: TONE_15, fontWeight: 300, fontStyle: 'italic' }}>
          {empty}
        </div>
      )}
    </div>
  )

  return (
    <div style={{ padding: '14px 8px' }}>
      <Group title="Links" icon={ArrowUpRight} empty="None">
        {skill.links?.length > 0 && skill.links.map((l, i) => (
          <ConnItem key={i} uri={l.uri || l} color={TYPE_META.skill.color}
            onClick={() => onNavigate(l.uri || l)} />
        ))}
      </Group>
      <Group title="Related" icon={Layers} empty="None">
        {skill.related?.length > 0 && skill.related.map((r, i) => (
          <ConnItem key={i} uri={r.uri} label={r.relation} color={TYPE_META.context.color}
            onClick={() => onNavigate({ uri: r.uri })} />
        ))}
      </Group>
      <Group title="Backlinks" icon={LinkIcon} empty="None">
        {backlinks?.length > 0 && backlinks.map((bl, i) => (
          <ConnItem key={i} uri={bl.from} label={bl.type} color={TYPE_META.ecosystem.color}
            onClick={() => onNavigate({ uri: bl.from })} />
        ))}
      </Group>
      <Group title="Deps" icon={ExternalLink} empty="None">
        {skill.depends?.length > 0 && skill.depends.map((d, i) => (
          <ConnItem key={i} uri={d.uri} label={d.optional ? 'opt' : ''} color={TYPE_META.standard.color}
            onClick={() => onNavigate({ uri: d.uri })} />
        ))}
      </Group>
    </div>
  )
}

// ─── Main App ─────────────────────────────────────────

export default function App() {
  const [ecosystems, setEcosystems] = useState(DEFAULT_ECOSYSTEMS)
  const [trees, setTrees] = useState({})
  const [expandedNodes, setExpandedNodes] = useState(new Set(DEFAULT_ECOSYSTEMS))
  const [selectedSkill, setSelectedSkill] = useState(null)
  const [backlinks, setBacklinks] = useState([])
  const [focusedSectionId, setFocusedSectionId] = useState(null)
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [searchFocused, setSearchFocused] = useState(false)
  const [theme, setTheme] = useState(getPreferredTheme)

  useEffect(() => {
    const s = document.createElement('style')
    s.textContent = STYLES
    document.head.appendChild(s)
    return () => document.head.removeChild(s)
  }, [])

  useEffect(() => {
    window.localStorage?.setItem(THEME_STORAGE_KEY, theme)
  }, [theme])

  useEffect(() => {
    const fetchAll = async () => {
      setLoading(true)
      let ecosystemUris = DEFAULT_ECOSYSTEMS
      try {
        const res = await fetch('/v1/ecosystems')
        if (res.ok) {
          const data = await res.json()
          const fromApi = Array.isArray(data.ecosystems)
            ? data.ecosystems.map(item => item?.uri).filter(Boolean)
            : []
          if (fromApi.length > 0) ecosystemUris = sortEcosystems(fromApi)
        }
      } catch { /* fallback to defaults */ }

      const t = {}
      for (const eco of ecosystemUris) {
        try {
          const res = await fetch(`/v1/tree/${eco}`)
          if (res.ok) t[eco] = await res.json()
        } catch { /* skip */ }
      }
      const available = ecosystemUris.filter(eco => t[eco]?.uri)
      setTrees(t)
      setEcosystems(available)
      setExpandedNodes(prev => new Set([...prev, ...available]))
      setLoading(false)
      if (available.length > 0) handleSelect(t[available[0]])
    }
    fetchAll()
  }, [])

  const toggleNode = (uri, e) => {
    e?.stopPropagation()
    setExpandedNodes(prev => { const n = new Set(prev); n.has(uri) ? n.delete(uri) : n.add(uri); return n })
  }

  const handleSelect = async (nodeOrUri) => {
    const uri = typeof nodeOrUri === 'string' ? nodeOrUri : nodeOrUri?.uri
    if (!uri) return
    const { baseUri, sectionId } = splitTargetUri(uri)
    setFocusedSectionId(sectionId || null)

    try {
      const res = await fetch(`/v1/skills/${baseUri}`)
      if (res.ok) { const d = await res.json(); setSelectedSkill(d.skill || d) }
      else setSelectedSkill({ uri: baseUri })
    } catch { setSelectedSkill({ uri: baseUri }) }
    try {
      const blRes = await fetch(`/v1/backlinks/${baseUri}`)
      if (blRes.ok) { const d = await blRes.json(); setBacklinks(d.backlinks || []) }
      else setBacklinks([])
    } catch { setBacklinks([]) }
    setExpandedNodes(prev => new Set([...prev, ...getAncestorUris(baseUri)]))
  }

  // Filter tree based on search query
  const filterTree = (node, query) => {
    if (!node) return null;
    if (!query) return node;
    const q = query.toLowerCase();
    const name = node.name || node.uri.split('/').pop();
    const matches = name.toLowerCase().includes(q) || node.uri.toLowerCase().includes(q);
    
    if (matches) return node; // If this node matches, show it and all its children
    
    if (!node.skills) return null;
    
    const filteredSkills = node.skills.map(child => filterTree(child, query)).filter(Boolean);
    
    if (filteredSkills.length > 0) {
      return { ...node, skills: filteredSkills };
    }
    return null;
  };

  // Auto-expand during search
  useEffect(() => {
    if (searchQuery.length > 1) {
      setExpandedNodes(prev => {
        const newExpanded = new Set(prev);
        const expandPath = (node) => {
          if (!node || !node.skills) return false;
          const q = searchQuery.toLowerCase();
          const name = node.name || node.uri.split('/').pop();
          const matches = name.toLowerCase().includes(q) || node.uri.toLowerCase().includes(q);
          
          let childMatched = false;
          for (const child of node.skills) {
            if (expandPath(child)) childMatched = true;
          }
          
          if (childMatched || matches) {
            newExpanded.add(node.uri);
            return true;
          }
          return false;
        };
        
        ecosystems.forEach(eco => {
          expandPath(trees[eco]);
        });
        return newExpanded;
      });
    }
  }, [searchQuery, trees, ecosystems]);

  return (
    <div className={APP_SHELL_CLASS} data-theme={theme} style={{
      display: 'flex', height: '100vh', width: '100vw',
      fontFamily: "'Satoshi', sans-serif",
      color: TEXT_PRIMARY, background: APP_BG, overflow: 'hidden',
      position: 'relative',
    }}>
      {/* Sidebar */}
      <div style={{
        width: 272, flexShrink: 0, display: 'flex', flexDirection: 'column',
        borderRight: `1px solid ${TONE_06}`,
        background: PANEL_BG,
        backdropFilter: 'blur(20px)',
        zIndex: 1,
      }}>
        {/* Logo */}
        <div style={{
          padding: '16px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
          borderBottom: `1px solid ${TONE_06}`,
        }}>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontFamily: "'Fraunces', serif", fontSize: 17, fontWeight: 400, color: TEXT_PRIMARY, lineHeight: 1 }}>
              dojo
            </span>
            <span style={{ fontSize: 10, color: TEXT_PRIMARY, fontFamily: "'DM Mono'", marginTop: 2 }}>
the agent knowledge layer
            </span>
          </div>
          <ThemeToggle theme={theme} onToggle={() => setTheme(currentTheme => currentTheme === 'dark' ? 'light' : 'dark')} />
        </div>

        {/* Search */}
        <div style={{ padding: '12px 14px', borderBottom: `1px solid ${TONE_06}` }}>
          <div style={{
            position: 'relative',
            borderRadius: 8,
            transition: 'box-shadow 0.2s ease',
            boxShadow: searchFocused ? `0 0 0 1px ${ACCENT}40, 0 0 12px ${ACCENT}10` : 'none',
          }}>
            <Search style={{
              width: 14, height: 14, position: 'absolute', left: 11, top: '50%', transform: 'translateY(-50%)',
              color: searchFocused ? ACCENT : TONE_20, transition: 'color 0.2s',
            }} />
            <input type="text" placeholder="Search nodes..." value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              onFocus={() => setSearchFocused(true)}
              onBlur={() => setSearchFocused(false)}
              style={{
                width: '100%', padding: '8px 12px 8px 34px', fontSize: 13, borderRadius: 8, boxSizing: 'border-box',
                border: `1px solid ${TONE_08}`, background: TONE_03,
                color: TEXT_PRIMARY, outline: 'none', fontFamily: "'Satoshi', sans-serif",
                transition: 'border-color 0.2s',
              }}
            />
          </div>
        </div>

        {/* Tree */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '10px 8px' }}>
          {loading ? (
            <div style={{ padding: 24, textAlign: 'center' }}>
              <div style={{
                width: 24, height: 24, border: `2px solid ${ACCENT}30`, borderTopColor: ACCENT,
                borderRadius: '50%', margin: '0 auto 12px',
                animation: 'spin 0.8s linear infinite',
              }} />
              <span style={{ fontSize: 12, color: TEXT_PRIMARY, fontWeight: 300 }}>Loading trees...</span>
              <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
            </div>
          ) : (
            ecosystems.map((eco, i) => {
              const node = filterTree(trees[eco], searchQuery)
              if (!node || !node.uri) return null
              return <TreeNode key={eco} node={node} depth={0} index={i}
                expandedNodes={expandedNodes} toggleNode={toggleNode}
                selectedSkill={selectedSkill} handleSelect={handleSelect} />
            })
          )}
        </div>

        {/* Legend */}
        <div style={{
          padding: '12px 16px', borderTop: `1px solid ${TONE_06}`,
          display: 'flex', flexWrap: 'wrap', gap: 10,
        }}>
          {Object.entries(TYPE_META).map(([type, m]) => (
            <span key={type} style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 10, color: TEXT_PRIMARY }}>
              <span style={{ width: 5, height: 5, borderRadius: '50%', background: m.color, boxShadow: `0 0 4px ${m.color}40` }} />
              {type}
            </span>
          ))}
        </div>
      </div>

      {/* Main */}
      <div style={{ flex: 1, overflowY: 'auto', zIndex: 1 }}>
        <DetailView skill={selectedSkill} backlinks={backlinks} onNavigate={handleSelect} focusedSectionId={focusedSectionId} />
      </div>

      {/* Right panel */}
      <div style={{
        width: 228, flexShrink: 0,
        borderLeft: `1px solid ${TONE_06}`,
        background: PANEL_BG,
        backdropFilter: 'blur(20px)',
        overflowY: 'auto', zIndex: 1,
      }}>
        <div style={{
          padding: '16px 16px', borderBottom: `1px solid ${TONE_06}`,
          display: 'flex', alignItems: 'center', gap: 7,
        }}>
          <LinkIcon style={{ width: 13, height: 13, color: TONE_25 }} />
          <span style={{ fontSize: 12, fontWeight: 500, color: TEXT_PRIMARY }}>Connections</span>
        </div>
        <ConnectionsPanel skill={selectedSkill} backlinks={backlinks} onNavigate={handleSelect} />
      </div>
    </div>
  )
}
