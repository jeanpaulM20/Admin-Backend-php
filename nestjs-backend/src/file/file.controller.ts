import {
  Controller, Get, Post, Delete, Param, Body, Query, Res,
  ParseIntPipe, HttpException, HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';
import { FileService } from './file.service';
import * as https from 'https';
import * as http from 'http';

@Controller('api/file')
export class FileController {
  constructor(private readonly service: FileService) {}

  /**
   * GET /api/file?client_id=X — files for one client
   * GET /api/file              — all files
   * Returns file metadata with secure download URL (proxied through this server)
   */
  @Get()
  async findAll(@Query('client_id') clientId?: string) {
    try {
      let files;
      if (clientId) {
        files = await this.service.findByClient(+clientId);
      } else {
        files = await this.service.findAll();
      }
      // Replace direct file URLs with proxied URLs
      return files.map((f: any) => this.service.formatFileForApi(f));
    } catch (err) {
      throw new HttpException(
        { message: err.message },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** GET /api/file/:id — file metadata */
  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number) {
    const file = await this.service.findOne(id);
    if (!file) {
      throw new HttpException('File not found', HttpStatus.NOT_FOUND);
    }
    return {
      ...file,
      file: file.file ? `/api/file/${file.id}/download` : null,
      file_original: file.file,
    };
  }

  /**
   * GET /api/file/:id/download — secure file proxy
   * Streams file content through this server (requires auth via guard).
   * The actual file URL on the old server is never exposed to the client.
   */
  @Get(':id/download')
  async download(
    @Param('id', ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    const file = await this.service.findOneRaw(id);
    if (!file) {
      throw new HttpException('File not found', HttpStatus.NOT_FOUND);
    }
    if (!file.file) {
      throw new HttpException('No file URL available', HttpStatus.NOT_FOUND);
    }

    const fileUrl = file.file;

    // Determine filename for Content-Disposition
    const urlPath = new URL(fileUrl).pathname;
    const filename = decodeURIComponent(urlPath.split('/').pop() || 'file');

    // Determine content type from extension
    const ext = filename.split('.').pop()?.toLowerCase();
    const contentTypes: Record<string, string> = {
      pdf: 'application/pdf',
      jpg: 'image/jpeg',
      jpeg: 'image/jpeg',
      png: 'image/png',
      gif: 'image/gif',
      doc: 'application/msword',
      docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      xls: 'application/vnd.ms-excel',
      xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
    const contentType = contentTypes[ext || ''] || 'application/octet-stream';

    // Proxy the file from the original server
    try {
      const parsedUrl = new URL(fileUrl);
      const mod = fileUrl.startsWith('https') ? https : http;
      const proxyReq = mod.get(
        {
          hostname: parsedUrl.hostname,
          path: parsedUrl.pathname + parsedUrl.search,
          headers: {
            'User-Agent': 'SihlTraining/1.0',
            Accept: '*/*',
          },
        },
        (proxyRes) => {
          // Follow redirects (301/302)
          if (
            (proxyRes.statusCode === 301 || proxyRes.statusCode === 302) &&
            proxyRes.headers.location
          ) {
            const redirectMod = proxyRes.headers.location.startsWith('https')
              ? https
              : http;
            redirectMod.get(proxyRes.headers.location, (redirectRes) => {
              if (redirectRes.statusCode !== 200) {
                res
                  .status(redirectRes.statusCode || 502)
                  .json({ message: 'File redirect failed' });
                return;
              }
              res.setHeader('Content-Type', contentType);
              res.setHeader(
                'Content-Disposition',
                `inline; filename="${filename}"`,
              );
              if (redirectRes.headers['content-length']) {
                res.setHeader(
                  'Content-Length',
                  redirectRes.headers['content-length'],
                );
              }
              res.setHeader('X-Content-Type-Options', 'nosniff');
              res.setHeader('Cache-Control', 'private, max-age=3600');
              redirectRes.pipe(res);
            });
            return;
          }

          if (proxyRes.statusCode !== 200) {
            res.status(proxyRes.statusCode || 502).json({
              message: `File could not be retrieved from storage (${proxyRes.statusCode})`,
            });
            return;
          }

        res.setHeader('Content-Type', contentType);
        res.setHeader(
          'Content-Disposition',
          `inline; filename="${filename}"`,
        );
        if (proxyRes.headers['content-length']) {
          res.setHeader('Content-Length', proxyRes.headers['content-length']);
        }
        // Security headers
        res.setHeader('X-Content-Type-Options', 'nosniff');
        res.setHeader('Cache-Control', 'private, max-age=3600');

        proxyRes.pipe(res);
      });

      proxyReq.on('error', () => {
        if (!res.headersSent) {
          res.status(502).json({ message: 'Failed to fetch file from storage' });
        }
      });

      proxyReq.setTimeout(30000, () => {
        proxyReq.destroy();
        if (!res.headersSent) {
          res.status(504).json({ message: 'File download timed out' });
        }
      });
    } catch (err) {
      throw new HttpException(
        'Failed to proxy file',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /** POST /api/file/send — create file record (upload handled by client) */
  @Post('send')
  async send(@Body() body: any) {
    try {
      return await this.service.create({
        name: body.name,
        file: body.file,
        clientId: body.client_id ? +body.client_id : undefined,
        date: body.date || new Date().toISOString().slice(0, 10),
      });
    } catch (err) {
      throw new HttpException(
        { message: err.message },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** POST /api/file — create file record */
  @Post()
  async create(@Body() body: any) {
    try {
      return await this.service.create({
        name: body.name,
        file: body.file,
        clientId: body.client_id ? +body.client_id : undefined,
        date: body.date || new Date().toISOString().slice(0, 10),
      });
    } catch (err) {
      throw new HttpException(
        { message: err.message },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** DELETE /api/file/:id */
  @Delete(':id')
  async remove(@Param('id', ParseIntPipe) id: number) {
    await this.service.remove(id);
    return { success: true };
  }
}
