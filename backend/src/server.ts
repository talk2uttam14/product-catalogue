import { createServer, type Server } from 'node:http';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createApp } from './app.js';
import { loadConfig, type AppConfig } from './config/env.js';

const SHUTDOWN_TIMEOUT_MS = 10_000;

export function startServer(config: AppConfig): Server {
  const server = createServer(createApp(config));

  server.once('listening', () => {
    console.info(`Backend listening at http://${config.host}:${config.port}`);
  });
  server.on('error', (error: NodeJS.ErrnoException) => {
    // Error messages can include internal paths or host details; only log the stable code.
    console.error(`HTTP server startup failed${error.code ? ` (${error.code})` : ''}.`);
    process.exitCode = 1;
  });

  server.listen(config.port, config.host);
  return server;
}

function runServer(): void {
  const server = startServer(loadConfig());
  let isShuttingDown = false;

  const shutDown = (signal: 'SIGINT' | 'SIGTERM'): void => {
    if (isShuttingDown) return;
    isShuttingDown = true;

    console.info(`Received ${signal}; shutting down HTTP server.`);
    const timeout = setTimeout(() => {
      console.error('HTTP server shutdown timed out; remaining connections will be closed.');
      process.exitCode = 1;
      server.closeAllConnections();
    }, SHUTDOWN_TIMEOUT_MS);

    server.close((error) => {
      clearTimeout(timeout);
      if (error) {
        console.error('HTTP server shutdown failed.');
        process.exitCode = 1;
        return;
      }

      console.info('HTTP server stopped.');
    });
  };

  process.once('SIGINT', () => shutDown('SIGINT'));
  process.once('SIGTERM', () => shutDown('SIGTERM'));
}

function isMainModule(): boolean {
  const entryPath = process.argv[1];
  return entryPath !== undefined && pathToFileURL(resolve(entryPath)).href === import.meta.url;
}

if (isMainModule()) {
  try {
    runServer();
  } catch {
    console.error('Backend startup failed because environment configuration is invalid.');
    process.exitCode = 1;
  }
}
