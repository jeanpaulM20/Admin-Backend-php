import {
  Controller, Get, Post, Delete, Param, Body, Query,
  ParseIntPipe, HttpException, HttpStatus,
} from '@nestjs/common';
import { FileService } from './file.service';

@Controller('api/file')
export class FileController {
  constructor(private readonly service: FileService) {}

  /**
   * GET /api/file?client_id=X — files for one client
   * GET /api/file              — all files
   */
  @Get()
  async findAll(@Query('client_id') clientId?: string) {
    try {
      if (clientId) {
        return await this.service.findByClient(+clientId);
      }
      return await this.service.findAll();
    } catch (err) {
      throw new HttpException(
        { message: err.message },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** GET /api/file/:id */
  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number) {
    const file = await this.service.findOne(id);
    if (!file) {
      throw new HttpException('File not found', HttpStatus.NOT_FOUND);
    }
    return file;
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
