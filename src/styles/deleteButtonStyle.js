export default {
  background: '0 0',
  border: 'none',
  borderRadius: 2,
  color: '#000',
  position: 'relative',
  height: 36,
  minWidth: 64,
  padding: '0 16px',
  display: 'inline-block',
  fontFamily: '"Roboto","Helvetica","Arial",sans-serif',
  fontSize: 14,
  fontWeight: 500,
  textTransform: 'uppercase',
  letterSpacing: 0,
  overflow: 'hidden',
  willChange: 'box-shadow,transform',
  WebkitTransition: 'box-shadow .2s cubic-bezier(.4,0,1,1),background-color .2s cubic-bezier(.4,0,.2,1),color .2s cubic-bezier(.4,0,.2,1)',
  transition: 'box-shadow .2s cubic-bezier(.4,0,1,1),background-color .2s cubic-bezier(.4,0,.2,1),color .2s cubic-bezier(.4,0,.2,1)',
  outline: 'none',
  cursor: 'pointer',
  textDecoration: 'none',
  textAlign: 'center',

  // `36` does not automatically have 'px' added to it, is interpreted as...
  // something bigger
  lineHeight: '36px',
  verticalAlign: 'middle',
};
