import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { FileEntity } from '../entities/file.entity';

@Injectable()
export class FileService {
  constructor(
    @InjectRepository(FileEntity)
    private readonly fileRepo: Repository<FileEntity>,
  ) {}

  private formatFile(f: FileEntity) {
    return {
      id: f.id,
      name: f.name,
      date: f.date,
      file: f.file,
      client_id: f.clientId,
    };
  }

  async findByClient(clientId: number) {
    const rows = await this.fileRepo.find({
      where: { clientId },
      order: { date: 'DESC' },
    });
    return rows.map((f) => this.formatFile(f));
  }

  async findAll() {
    const rows = await this.fileRepo.find({
      order: { date: 'DESC' },
    });
    return rows.map((f) => this.formatFile(f));
  }

  async findOne(id: number) {
    const f = await this.fileRepo.findOne({ where: { id } });
    return f ? this.formatFile(f) : null;
  }

  async create(data: Partial<FileEntity>): Promise<FileEntity> {
    const entity = this.fileRepo.create(data);
    return this.fileRepo.save(entity);
  }

  async update(id: number, data: Partial<FileEntity>): Promise<FileEntity | null> {
    await this.fileRepo.update(id, data);
    const f = await this.fileRepo.findOne({ where: { id } });
    return f;
  }

  async remove(id: number): Promise<void> {
    await this.fileRepo.delete(id);
  }
}
