import {createTheme} from '@mui/material/styles';

export const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: {main: '#d0a7ff'},
    secondary: {main: '#bba0d8'},
    background: {default: '#141218', paper: '#211e27'},
    text: {primary: '#f2edf6', secondary: '#c4bdca'},
    success: {main: '#69f0ae'},
    error: {main: '#ff8a80'},
    warning: {main: '#ffd180'},
    info: {main: '#b7a0d6'},
  },
  typography: {
    fontFamily: 'Roboto, "Segoe UI", Arial, sans-serif',
    fontSize: 13,
    button: {fontWeight: 600, textTransform: 'none'},
    h6: {fontSize: '1.05rem', fontWeight: 600},
    subtitle1: {fontSize: '0.95rem', fontWeight: 600},
    body2: {fontSize: '0.82rem'},
    caption: {fontSize: '0.72rem'},
  },
  shape: {borderRadius: 10},
  components: {
    MuiAppBar: {
      styleOverrides: {root: {backgroundColor: '#25222c', backgroundImage: 'none'}},
    },
    MuiToolbar: {
      styleOverrides: {root: {minHeight: '56px !important', paddingInline: '16px !important'}},
    },
    MuiTabs: {
      styleOverrides: {
        root: {minHeight: 62, backgroundColor: '#211e27'},
        indicator: {height: 2, borderRadius: 2, backgroundColor: '#d0a7ff'},
      },
    },
    MuiTab: {
      styleOverrides: {
        root: {
          minHeight: 62,
          minWidth: 0,
          gap: 2,
          padding: '7px 12px 6px',
          color: '#c4bdca',
          fontSize: '0.76rem',
          '&.Mui-selected': {color: '#d0a7ff'},
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        root: {minHeight: 32, borderRadius: 999, paddingInline: 12, whiteSpace: 'nowrap'},
        startIcon: {marginRight: 6},
      },
    },
    MuiIconButton: {
      styleOverrides: {root: {padding: 8}},
    },
    MuiOutlinedInput: {
      styleOverrides: {
        root: {borderRadius: 8, backgroundColor: '#17151b'},
        input: {padding: '9px 12px', fontSize: '0.84rem'},
      },
    },
    MuiInputLabel: {
      styleOverrides: {root: {fontSize: '0.84rem'}},
    },
    MuiPaper: {
      styleOverrides: {root: {backgroundImage: 'none'}},
    },
    MuiCard: {
      styleOverrides: {
        root: {backgroundColor: '#201d25', border: '1px solid #302c37', boxShadow: '0 2px 8px #0003'},
      },
    },
    MuiTooltip: {
      styleOverrides: {tooltip: {fontSize: '0.74rem'}},
    },
    MuiMenuItem: {
      styleOverrides: {root: {minHeight: 36, fontSize: '0.82rem'}},
    },
  },
});
