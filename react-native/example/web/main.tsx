import React from 'react';
import {createRoot} from 'react-dom/client';
import {CssBaseline, ThemeProvider} from '@mui/material';
import App from './App';
import {theme} from './theme';
import './styles.css';

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <App />
    </ThemeProvider>
  </React.StrictMode>,
);
